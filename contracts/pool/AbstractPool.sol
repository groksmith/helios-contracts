// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";

abstract contract AbstractPool is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PoolLibrary for PoolLibrary.DepositsStorage;

    string public constant NAME = "Helios Pool TKN";
    string public constant SYMBOL = "HLS-P";

    IERC20 public immutable asset; // The asset deposited by Lenders into the Pool
    IPoolFactory public immutable poolFactory; // The Pool factory that deployed this Pool

    PoolLibrary.DepositsStorage private depositsStorage;
    PoolLibrary.PoolInfo public poolInfo;

    uint256 public totalDeposited;
    uint256 public principalOut;

    mapping(address => uint256) public yields;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public pendingYields;

    uint256 public withdrawLimit; // Maximum amount that can be withdrawn in a period
    uint256 public withdrawPeriod; // Timeframe for the withdrawal limit

    event Deposit(address indexed investor, uint256 amount);
    event Withdrawal(address indexed investor, uint256 amount);
    event PendingWithdrawal(address indexed investor, uint256 amount);
    event PendingWithdrawalConcluded(address indexed investor, uint256 amount);
    event YieldWithdrawn(address indexed recipient, uint256 amount);
    event PendingYield(address indexed recipient, uint256 amount);
    event PendingYieldConcluded(address indexed recipient, uint256 amount);
    event WithdrawalOverThreshold(address indexed caller, uint256 amount);
    event BalanceUpdated(address indexed pool, address indexed token, uint256 balance);

    constructor(
        address _asset,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _withdrawLimit,
        uint256 _withdrawPeriod
    ) ERC20(_tokenName, _tokenSymbol) {
        poolFactory = IPoolFactory(msg.sender);

        require(_asset != address(0), "P:ZERO_LIQ_ASSET");
        require(poolFactory.globals().isValidAsset(_asset), "P:INVALID_LIQ_ASSET");

        asset = IERC20(_asset);

        withdrawLimit = _withdrawLimit;
        withdrawPeriod = _withdrawPeriod;
    }

    /*
    Investor flow
    */

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external virtual;

    /// @notice withdraws the caller's liquidity assets
    /// @param  _amount to be withdrawn
    function withdraw(uint256 _amount) public whenProtocolNotPaused {
        require(balanceOf(msg.sender) >= _amount, "P:INSUFFICIENT_FUNDS");
        require(unlockedToWithdraw(msg.sender) >= _amount, "P:TOKENS_LOCKED");

        _burn(msg.sender, _amount);

        _transferFunds(msg.sender, _amount);
        _emitBalanceUpdatedEvent();
        emit Withdrawal(msg.sender, _amount);
    }

    /// @notice check how much funds already unlocked
    function unlockedToWithdraw(address _user) public view returns (uint256) {
        return balanceOf(msg.sender) - depositsStorage.lockedDepositsAmount(_user);
    }

    /// @notice Used to transfer the investor's yields to him
    function withdrawYield() external virtual returns (bool) {
        uint256 callerYields = yields[msg.sender];
        yields[msg.sender] = 0;

        if (totalBalance() < callerYields) {
            pendingYields[msg.sender] += callerYields;
            emit PendingYield(msg.sender, callerYields);
            return false;
        }

        require(_transferFunds(msg.sender, callerYields), "P:ERROR_TRANSFERRING_YIELD");

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
        for (uint256 i = 0; i < depositsStorage.getHoldersCount(); i++) {
            address holder = depositsStorage.getHolderByIndex(i);
            yields[holder] += _calculateYield(holder, _amount);
        }
    }

    /// @notice Admin function used for unhappy path after withdrawal failure
    /// @param _recipient address of the recipient who didn't get the liquidity
    function concludePendingWithdrawal(address _recipient) external nonReentrant onlyAdmin {
        uint256 amount = pendingWithdrawals[_recipient];
        require(_transferFunds(_recipient, amount), "P:CONCLUDE_WITHDRAWAL_FAILED");

        //remove from pendingWithdrawals mapping:
        delete pendingWithdrawals[_recipient];
        emit PendingWithdrawalConcluded(_recipient, amount);
    }

    /// @notice Admin function used for unhappy path after yield withdraw failure
    /// @param _recipient address of the recipient who didn't get the yield
    function concludePendingYield(address _recipient) external nonReentrant onlyAdmin {
        uint256 amount = pendingYields[_recipient];
        require(_transferFunds(_recipient, amount), "P:CONCLUDE_YIELD_FAILED");

        //remove from pendingWithdrawals mapping:
        delete pendingYields[_recipient];
        emit PendingYieldConcluded(_recipient, amount);
    }

    /// @notice Borrow the pool's money for investment
    function borrow(address _to, uint256 _amount) external onlyAdmin {
        principalOut += _amount;
        _transferFunds(_to, _amount);
    }

    /// @notice Repay asset without minimal threshold or getting LP in return
    function repay(uint256 _amount) external onlyAdmin {
        require(asset.balanceOf(msg.sender) >= _amount, "P:NOT_ENOUGH_BALANCE");
        if (_amount >= principalOut) {
            principalOut = 0;
        } else {
            principalOut -= _amount;
        }

        asset.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /*
    Helpers
    */

    /// @notice Get Deposits Holders instance
    function getHolderByIndex(uint256 index) external view returns (address) {
        return depositsStorage.getHolderByIndex(index);
    }

    /// @notice Get Deposits Holders Count
    function getHoldersCount() external view returns (uint256) {
        return depositsStorage.getHoldersCount();
    }

    /// @notice Get the amount of Liquidity Assets in the Pool
    function totalBalance() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function decimals() public view override returns (uint8) {
        return ERC20(address(asset)).decimals();
    }

    function getPoolInfo() public view returns (PoolLibrary.PoolInfo memory) {
        return poolInfo;
    }

    /*
    Internals
    */

    function _calculateYield(address _holder, uint256 _amount) internal view virtual returns (uint256);

    function _depositLogic(uint256 _amount) internal {
        require(_amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");

        depositsStorage.addDeposit(msg.sender, _amount, block.timestamp + withdrawPeriod);

        asset.safeTransferFrom(msg.sender, address(this), _amount);

        _mintAndUpdateTotalDeposited(msg.sender, _amount);

        _emitBalanceUpdatedEvent();
        emit Deposit(msg.sender, _amount);
    }

    /// @notice  Mint Pool assets to given `to` address
    function _mintAndUpdateTotalDeposited(address _account, uint256 _amount) internal {
        _mint(_account, _amount);
        totalDeposited += _amount;
    }

    /// @notice  Transfers Pool assets to given `to` address
    function _transferFunds(address _to, uint256 _value) internal returns (bool) {
        return asset.transfer(_to, _value);
    }

    // Emits a `BalanceUpdated` event for Pool
    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(address(this), address(this), totalBalance());
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
