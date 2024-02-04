// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ILiquidityLocker} from "../interfaces/ILiquidityLocker.sol";
import {ILiquidityLockerFactory} from "../interfaces/ILiquidityLockerFactory.sol";
import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";
import {DepositsHolder} from "./DepositsHolder.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";

abstract contract AbstractPool is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    string public constant NAME = "Helios Pool TKN";
    string public constant SYMBOL = "HLS-P";

    ILiquidityLocker public immutable liquidityLocker; // The LiquidityLocker owned by this contract
    IERC20 public immutable liquidityAsset; // The asset deposited by Lenders into the LiquidityLocker
    IPoolFactory public immutable poolFactory; // The Pool factory that deployed this Pool

    uint256 public totalDeposited;
    uint256 public principalOut;

    mapping(address => uint256) public yields;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public pendingYields;

    DepositsHolder public depositsHolder;

    uint256 public withdrawLimit; // Maximum amount that can be withdrawn in a period
    uint256 public withdrawPeriod; // Timeframe for the withdrawal limit

    event Deposit(address indexed investor, uint256 indexed amount);
    event Withdrawal(address indexed investor, uint256 indexed amount);
    event PendingWithdrawal(address indexed investor, uint256 indexed amount);
    event PendingWithdrawalConcluded(address indexed investor, uint256 indexed amount);
    event YieldWithdrawn(address indexed recipient, uint256 indexed amount);
    event ReinvestYield(address indexed investor, uint256 indexed amount);
    event PendingYield(address indexed recipient, uint256 indexed amount);
    event PendingYieldConcluded(address indexed recipient, uint256 indexed amount);
    event WithdrawalOverThreshold(address indexed caller, uint256 indexed amount);
    event BalanceUpdated(address indexed liquidityProvider, address indexed token, uint256 balance);

    PoolLibrary.PoolInfo public poolInfo;

    constructor(
        address _liquidityAsset,
        address _liquidityLockerFactory,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _withdrawLimit,
        uint256 _withdrawPeriod
    ) ERC20(_tokenName, _tokenSymbol) {
        depositsHolder = new DepositsHolder();

        require(_liquidityAsset != address(0), "P:ZERO_LIQ_ASSET");
        require(_liquidityLockerFactory != address(0), "P:ZERO_LIQ_LOCKER_FACTORY");

        poolFactory = IPoolFactory(msg.sender);

        require(poolFactory.globals().isValidLiquidityAsset(_liquidityAsset), "P:INVALID_LIQ_ASSET");
        require(poolFactory.globals().isValidLiquidityLockerFactory(_liquidityLockerFactory), "P:INVALID_LL_FACTORY");

        liquidityAsset = IERC20(_liquidityAsset);

        ILiquidityLockerFactory liquidityLockerFactory = ILiquidityLockerFactory(_liquidityLockerFactory);
        liquidityLocker = ILiquidityLocker(liquidityLockerFactory.CreateLiquidityLocker(_liquidityAsset));
        withdrawLimit = _withdrawLimit;
        withdrawPeriod = _withdrawPeriod;
    }

    /*
    Investor flow
    */

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external virtual;

    /// @notice withdraws the caller's liquidity assets
    /// @param  _amounts the amount of Liquidity Asset to be withdrawn
    /// @param  _indices the indices of the DepositsHolder's DepositInstance
    function withdraw(uint256[] calldata _amounts, uint16[] calldata _indices) public whenProtocolNotPaused {
        require(_amounts.length == _indices.length, "P:ARRAYS_INCONSISTENT");

        PoolLibrary.DepositInstance[] memory deposits = depositsHolder.getDepositsByHolder(msg.sender);

        for (uint256 i = 0; i < _indices.length; i++) {
            uint256 _index = _indices[i];
            uint256 _amount = _amounts[i];

            require(block.timestamp >= deposits[_index].unlockTime, "P:TOKENS_LOCKED");
            require(deposits[_index].amount >= _amount && balanceOf(msg.sender) >= _amount, "P:INSUFFICIENT_FUNDS");

            _burn(msg.sender, _amount);

            //unhappy path - the withdrawal is then added in the 'pending' to be processed by the admin
            if (liquidityLockerTotalBalance() < _amount) {
                pendingWithdrawals[msg.sender] += _amount;
                emit PendingWithdrawal(msg.sender, _amount);
                continue;
            }

            deposits[_index].amount -= _amount;

            if (deposits[_index].amount == 0) {
                depositsHolder.deleteDeposit(msg.sender, _index);
            }

            _transferLiquidityLockerFunds(msg.sender, _amount);
            _emitBalanceUpdatedEvent();
            emit Withdrawal(msg.sender, _amount);
        }
    }

    /// @notice Used to reinvest yields into more LP tokens
    /// @param  _amount the amount of yield to be converted into LP
    function reinvestYield(uint256 _amount) whenProtocolNotPaused external {
        require(_amount > 0, "P:INVALID_VALUE");
        require(yields[msg.sender] >= _amount, "P:INSUFFICIENT_BALANCE");

        _mintAndUpdateTotalDeposited(msg.sender, _amount);

        yields[msg.sender] -= _amount;
        _emitBalanceUpdatedEvent();
        emit ReinvestYield(msg.sender, _amount);
    }

    /// @notice check how much funds already unlocked
    function unlockedToWithdraw(address _user, uint256 _index) external view returns (uint256) {
        require(depositsHolder.getDepositsByHolder(_user).length >= _index, "P:INVALID_INDEX");

        PoolLibrary.DepositInstance memory depositInstance = depositsHolder.getDepositsByHolder(_user)[_index];
        if (block.timestamp >= depositInstance.unlockTime) {
            return depositInstance.amount;
        } else {
            return 0;
        }
    }

    /// @notice Used to transfer the investor's yields to him
    function withdrawYield() external virtual returns (bool) {
        uint256 callerYields = yields[msg.sender];
        uint256 totalBalance = liquidityLockerTotalBalance();
        yields[msg.sender] = 0;

        if (totalBalance < callerYields) {
            pendingYields[msg.sender] += callerYields;
            emit PendingYield(msg.sender, callerYields);
            return false;
        }

        require(_transferLiquidityLockerFunds(msg.sender, callerYields), "P:ERROR_TRANSFERRING_YIELD");

        emit YieldWithdrawn(msg.sender, callerYields);
        return true;
    }

    /*
    Admin flow
    */

    /// @notice Used to distribute yields among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    function distributeYields(uint256 _amount) external virtual onlyAdmin nonReentrant {
        require(_amount > 0, "P:INVALID_VALUE");
        for (uint256 i = 0; i < depositsHolder.getHoldersCount(); i++) {
            address holder = depositsHolder.getHolderByIndex(i);
            yields[holder] += _calculateYield(holder, _amount);
        }
    }

    /// @notice Admin function used for unhappy path after withdrawal failure
    /// @param _recipient address of the recipient who didn't get the liquidity
    function concludePendingWithdrawal(address _recipient) external nonReentrant onlyAdmin {
        uint256 amount = pendingWithdrawals[_recipient];
        require(_transferLiquidityLockerFunds(_recipient, amount), "P:CONCLUDE_WITHDRAWAL_FAILED");

        //remove from pendingWithdrawals mapping:
        delete pendingWithdrawals[_recipient];
        emit PendingWithdrawalConcluded(_recipient, amount);
    }

    /// @notice Admin function used for unhappy path after yield withdraw failure
    /// @param _recipient address of the recipient who didn't get the yield
    function concludePendingYield(address _recipient) external nonReentrant onlyAdmin {
        uint256 amount = pendingYields[_recipient];
        require(_transferLiquidityLockerFunds(_recipient, amount), "P:CONCLUDE_YIELD_FAILED");

        //remove from pendingWithdrawals mapping:
        delete pendingYields[_recipient];
        emit PendingYieldConcluded(_recipient, amount);
    }

    /// @notice Borrow the pool's money for investment
    function borrow(address _to, uint256 _amount) external onlyAdmin {
        principalOut += _amount;
        _transferLiquidityLockerFunds(_to, _amount);
    }

    /// @notice Repay liquidityAsset without minimal threshold or getting LP in return
    function repay(uint256 _amount) external onlyAdmin {
        require(liquidityAsset.balanceOf(msg.sender) >= _amount, "P:NOT_ENOUGH_BALANCE");
        if (_amount >= principalOut) {
            principalOut = 0;
        } else {
            principalOut -= _amount;
        }

        liquidityAsset.safeTransferFrom(msg.sender, address(liquidityLocker), _amount);
    }

    /*
    Helpers
    */

    /// @notice Get Liquidity Locker instance
    function getLiquidityLocker() external view returns (address) {
        return address(liquidityLocker);
    }

    /// @notice Get the amount of Liquidity Assets in the Pool
    function liquidityLockerTotalBalance() public view returns (uint256) {
        return liquidityLocker.totalBalance();
    }

    function decimals() public view override returns (uint8) {
        return ERC20(address(liquidityAsset)).decimals();
    }

    function getPoolInfo() public view returns (PoolLibrary.PoolInfo memory) {
        return poolInfo;
    }

    /*
    Internals
    */

    function _calculateYield(address _holder, uint256 _amount) internal view virtual returns (uint256);

    function _depositLogic(uint256 _amount, IERC20 _token) internal {
        require(_amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");

        depositsHolder.addDeposit(msg.sender, _token, _amount, block.timestamp + withdrawPeriod);

        _token.safeTransferFrom(msg.sender, address(liquidityLocker), _amount);

        _mintAndUpdateTotalDeposited(msg.sender, _amount);

        _emitBalanceUpdatedEvent();
        emit Deposit(msg.sender, _amount);
    }

    /// @notice  Transfers Liquidity Locker assets to given `to` address
    function _mintAndUpdateTotalDeposited(address _account, uint256 _amount) internal {
        _mint(_account, _amount);
        totalDeposited += _amount;
    }

    /// @notice  Transfers Liquidity Locker assets to given `to` address
    function _transferLiquidityLockerFunds(address _to, uint256 _value) internal returns (bool) {
        return liquidityLocker.transfer(_to, _value);
    }

    // Emits a `BalanceUpdated` event for LiquidityLocker
    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(address(liquidityLocker), address(liquidityAsset), liquidityLockerTotalBalance());
    }

    /*
    Modifiers
    */

    // Checks that the protocol is not in a paused state
    modifier whenProtocolNotPaused() {
        require(!poolFactory.globals().protocolPaused(), "P:PROTO_PAUSED");
        _;
    }

    modifier onlyAdmin() {
        require(poolFactory.globals().isAdmin(msg.sender), "PF:NOT_ADMIN");
        _;
    }
}
