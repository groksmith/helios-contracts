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

abstract contract AbstractPool is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    string public constant NAME = "Helios Pool TKN";
    string public constant SYMBOL = "HLS-P";

    ILiquidityLocker public immutable liquidityLocker; // The LiquidityLocker owned by this contract
    IERC20 public immutable liquidityAsset; // The asset deposited by Lenders into the LiquidityLocker
    IPoolFactory public immutable poolFactory; // The Pool factory that deployed this Pool

    uint256 public totalDeposited;
    uint256 public principalOut;

    mapping(address => uint256) public rewards;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public pendingRewards;

    mapping(address => DepositInstance[]) public userDeposits;

    uint256 public withdrawLimit; // Maximum amount that can be withdrawn in a period
    uint256 public withdrawPeriod; // Timeframe for the withdrawal limit

    event Deposit(address indexed investor, uint256 indexed amount);
    event Withdrawal(address indexed investor, uint256 indexed amount);
    event PendingWithdrawal(address indexed investor, uint256 indexed amount);
    event PendingWithdrawalConcluded(address indexed investor, uint256 indexed amount);
    event RewardClaimed(address indexed recipient, uint256 indexed amount);
    event Reinvest(address indexed investor, uint256 indexed amount);
    event PendingReward(address indexed recipient, uint256 indexed amount);
    event PendingRewardConcluded(address indexed recipient, uint256 indexed amount);
    event WithdrawalOverThreshold(address indexed caller, uint256 indexed amount);
    event BalanceUpdated(address indexed liquidityProvider, address indexed token, uint256 balance);

    enum State {
        Initialized,
        Finalized,
        Deactivated
    }

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 apy;
        uint256 duration;
        uint256 investmentPoolSize;
        uint256 minInvestmentAmount;
        uint256 withdrawThreshold;
    }

    struct DepositInstance {
        IERC20 token;
        uint256 amount;
        uint256 unlockTime;
    }

    PoolInfo public poolInfo;

    constructor(
        address _liquidityAsset,
        address _liquidityLockerFactory,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _withdrawLimit,
        uint256 _withdrawPeriod
    ) ERC20(_tokenName, _tokenSymbol) {
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
    function deposit(uint256 _amount) external virtual whenProtocolNotPaused nonReentrant {
        require(totalSupply() + _amount <= poolInfo.investmentPoolSize, "P:MAX_POOL_SIZE_REACHED");

        _depositLogic(_amount, liquidityLocker.liquidityAsset());
    }

    /// @notice withdraws the caller's liquidity assets
    /// @param  _amounts the amount of Liquidity Asset to be withdrawn
    /// @param  _indices the indices of the DepositInstance
    function withdraw(uint256[] calldata _amounts, uint16[] calldata _indices) public whenProtocolNotPaused {
        require(_amounts.length == _indices.length, "P:ARRAYS_INCONSISTENT");
        for (uint256 i = 0; i < _indices.length; i++) {
            uint256 _index = _indices[i];
            uint256 _amount = _amounts[i];
            require(_index < userDeposits[msg.sender].length, "P:INVALID_INDEX");
            DepositInstance memory aDeposit = userDeposits[msg.sender][_index];
            require(block.timestamp >= aDeposit.unlockTime, "P:TOKENS_LOCKED");
            require(aDeposit.amount >= _amount && balanceOf(msg.sender) >= _amount, "P:INSUFFICIENT_FUNDS");

            _burn(msg.sender, _amount);

            //unhappy path - the withdrawal is then added in the 'pending' to be processed by the admin
            if (liquidityLockerTotalBalance() < _amount) {
                pendingWithdrawals[msg.sender] += _amount;
                emit PendingWithdrawal(msg.sender, _amount);
                continue;
            }

            aDeposit.amount -= _amount;

            if (aDeposit.amount == 0) {
                removeDeposit(msg.sender, _index);
            }

            _transferLiquidityLockerFunds(msg.sender, _amount);
            _emitBalanceUpdatedEvent();
            emit Withdrawal(msg.sender, _amount);
        }
    }

    function removeDeposit(address _user, uint256 _index) private {
        uint256 lastIndex = userDeposits[_user].length - 1;
        if (_index != lastIndex) {
            userDeposits[_user][_index] = userDeposits[_user][lastIndex];
        }
        userDeposits[_user].pop();
    }

    /// @notice Used to reinvest rewards into more LP tokens
    /// @param  _amount the amount of rewards to be converted into LP
    function reinvest(uint256 _amount) whenProtocolNotPaused external {
        require(_amount > 0, "P:INVALID_VALUE");
        require(rewards[msg.sender] >= _amount, "P:INSUFFICIENT_BALANCE");

        _mintAndUpdateTotalDeposited(msg.sender, _amount);

        rewards[msg.sender] -= _amount;
        _emitBalanceUpdatedEvent();
        emit Reinvest(msg.sender, _amount);
    }

    /// @notice check how many funds
    function availableToWithdraw(address _user, uint256 _index) external view returns (uint256) {
        require(_index < userDeposits[_user].length, "P:INVALID_INDEX");
        DepositInstance memory depositInstance = userDeposits[_user][_index];
        if (block.timestamp >= depositInstance.unlockTime) {
            return depositInstance.amount;
        } else {
            return 0;
        }
    }

    function claimReward() external virtual returns (bool);

    /*
    Admin flow
    */

    function distributeRewards(uint256 _amount, address[] calldata _holders) external virtual;

    /// @notice Admin function used for unhappy path after withdrawal failure
    /// @param _recipient address of the recipient who didn't get the liquidity
    function concludePendingWithdrawal(address _recipient) external nonReentrant onlyAdmin {
        uint256 amount = pendingWithdrawals[_recipient];
        require(_transferLiquidityLockerFunds(_recipient, amount), "P:CONCLUDE_WITHDRAWAL_FAILED");

        //remove from pendingWithdrawals mapping:
        delete pendingWithdrawals[_recipient];
        emit PendingWithdrawalConcluded(_recipient, amount);
    }

    /// @notice Admin function used for unhappy path after reward claiming failure
    /// @param _recipient address of the recipient who didn't get the reward
    function concludePendingReward(address _recipient) external nonReentrant onlyAdmin {
        uint256 amount = pendingRewards[_recipient];
        require(_transferLiquidityLockerFunds(_recipient, amount), "P:CONCLUDE_REWARD_FAILED");

        //remove from pendingWithdrawals mapping:
        delete pendingRewards[_recipient];
        emit PendingRewardConcluded(_recipient, amount);
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

    /*
    Internals
    */

    function _depositLogic(uint256 _amount, IERC20 _token) internal {
        require(_amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");
        userDeposits[msg.sender].push(
            DepositInstance({token: _token, amount: _amount, unlockTime: block.timestamp + withdrawPeriod})
        );

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
