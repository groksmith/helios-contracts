// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IPoolFactory.sol";
import "../interfaces/ILiquidityLockerFactory.sol";
import "../interfaces/ILiquidityLocker.sol";
import "../interfaces/IHeliosGlobals.sol";
import "../library/PoolLib.sol";
import "../token/PoolFDT.sol";

import "hardhat/console.sol";

/// @title Blended Pool
contract BlendedPool is PoolFDT, Ownable, Pausable {
    using SafeMathUint for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    address public immutable superFactory; // The factory that deployed this Pool
    ILiquidityLocker public immutable liquidityLocker; // The LiquidityLocker owned by this contractLiqui //note: to be removed
    address public immutable poolDelegate; // The Pool Delegate address, maintains full authority over the Pool
    IERC20 public immutable liquidityAsset; // The asset deposited by Lenders into the LiquidityLocker
    IERC20 public immutable rewardToken; // The asset which represents reward token i.e. real world money
    uint256 private immutable liquidityAssetDecimals; // The precision for the Liquidity Asset (i.e. `decimals()`)

    uint256 public principalOut; // The sum of all outstanding principal on Loans.
    address public borrower; // Address of borrower for this Pool.
    mapping(address => bool) public pools; //TODO
    mapping(address => uint) public rewards;

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 apy;
        uint256 duration;
        uint256 minInvestmentAmount;
    }

    PoolInfo public poolInfo;

    event PoolAdminSet(address indexed poolAdmin, bool allowed);
    event BorrowerSet(address indexed borrower);
    event BalanceUpdated(
        address indexed liquidityProvider,
        address indexed token,
        uint256 balance
    );
    event Deposit(address indexed investor, uint256 amount);
    event Drawdown(
        address indexed borrower,
        uint256 amount,
        uint256 principalOut
    );
    event Payment(
        address indexed borrower,
        uint256 amount,
        uint256 principalOut
    );

    event Reward(address indexed recipient, uint256 amount);

    event RegPoolDeposit(address indexed regPool, uint256 amount);

    mapping(address => uint256) public depositDate; // Used for deposit/withdraw logic

    constructor(
        address _liquidityAsset,
        address _llFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _minInvestmentAmount
    ) PoolFDT(PoolLib.NAME, PoolLib.SYMBOL) Ownable(msg.sender) {
        require(_liquidityAsset != address(0), "P:ZERO_LIQ_ASSET");
        require(_llFactory != address(0), "P:ZERO_LIQ_LOCKER_FACTORY");

        liquidityAsset = IERC20(_liquidityAsset);
        liquidityAssetDecimals = ERC20(_liquidityAsset).decimals();

        superFactory = msg.sender;

        poolInfo = PoolInfo(
            _lockupPeriod,
            _apy,
            _duration,
            _minInvestmentAmount
        );

        liquidityLocker = ILiquidityLocker(
            ILiquidityLockerFactory(_llFactory).newLocker(_liquidityAsset)
        );
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        require(amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");

        PoolLib.updateDepositDate(
            depositDate,
            balanceOf(msg.sender),
            amount,
            msg.sender
        );
        liquidityAsset.safeTransferFrom(msg.sender, address(this), amount); //note: we're transferring tokens to this contract's address, not "liquidity locker"

        _mint(msg.sender, amount);

        _emitBalanceUpdatedEvent();
        emit Deposit(msg.sender, amount);
    }

    function withdrawableOf(address _holder) external view returns (uint256) {
        require(
            depositDate[_holder] + poolInfo.lockupPeriod <= block.timestamp,
            "P:FUNDS_LOCKED"
        );

        return
            Math.min(
                liquidityAsset.balanceOf(address(liquidityLocker)),
                super.balanceOf(_holder)
            );
    }

    function totalDeposited() external view returns (uint256) {
        return totalMinted;
    }

    function decimals() public view override returns (uint8) {
        return uint8(liquidityAssetDecimals);
    }

    function withdrawFundsAmount(
        uint256 _amount,
        address _holder
    ) public onlyOwner whenNotPaused {
        require(
            depositDate[_holder] + poolInfo.lockupPeriod <= block.timestamp,
            "P:FUNDS_LOCKED"
        );
        require(withdrawableFundsOf(msg.sender) > 0, "P:NOT_INVESTOR");
        uint256 withdrawableFunds = _prepareWithdraw(_amount);
        require(
            _amount <= withdrawableFunds,
            "P:INSUFFICIENT_WITHDRAWABLE_FUNDS"
        );

        _transferLiquidityLockerFunds(msg.sender, _amount);
        _emitBalanceUpdatedEvent();

        interestSum = interestSum - _amount;

        _updateFundsTokenBalance();
    }

    /// @notice Used to distribute payment among investors
    /// @param  _principalClaim the amount to be divided among investors
    /// @param  holders the investors
    function distributePayments(
        uint256 _principalClaim,
        address[] memory holders
    ) external onlyOwner nonReentrant {
        require(_principalClaim > 0, "P:ZERO_CLAIM");
        uint balance = liquidityLocker.totalSupply();

        require(balance < _principalClaim, "P:NOT_ENOUGH_BALANCE_IN_BPOOL");

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            uint256 holderBalance = balanceOf(holder);
            uint256 holderShare = (_principalClaim * holderBalance) /
                balance;
            rewards[holder] += holderShare;
        }
    }

    /// @notice Used to transfer the investor's rewards to him
    function claimReward() external {
        uint256 callerRewards = rewards[msg.sender];
        require(callerRewards >= 0, "P:NOT_HOLDER");

        require(
            _transferLiquidityLockerFunds(msg.sender, callerRewards),
            "P:ERROR_TRANSFERRING_REWARD"
        );

        emit Reward(msg.sender, callerRewards);
    }

    /// @notice Called by a RegPool when it doesn't have enough LA
    function requestLiquidityAssets(uint256 amountMissing) external onlyPool {
        require(amountMissing > 0, "P:INVALID_INPUT");
        require(totalSupplyLA() >= amountMissing, "P:NOT_ENOUGH_LA_BP");
        liquidityLocker.transfer(msg.sender, amountMissing);
        emit RegPoolDeposit(msg.sender, amountMissing);
    }

    /// @notice  Transfers Liquidity Locker assets to given `to` address
    function _transferLiquidityLockerFunds(
        address to,
        uint256 value
    ) internal returns (bool) {
        return _liquidityLocker().transfer(to, value);
    }

    // Emits a `BalanceUpdated` event for LiquidityLocker
    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(
            address(liquidityLocker),
            address(liquidityAsset),
            liquidityLocker.totalSupply()
        );
    }

    // Returns the LiquidityLocker instance
    function _liquidityLocker() internal view returns (ILiquidityLocker) {
        return ILiquidityLocker(liquidityLocker);
    }

    /// @notice Get the amount of Liquidity Assets in the Blended Pool
    function totalSupplyLA() public view returns (uint256) {
        return liquidityLocker.totalSupply();
    }

    /// @notice Used for unhappy path during payment failure TODO
    function finishWithdrawalProcess() external onlyOwner {}

    /// @notice Register a new pool to the Blended Pool
    function addPool(address _pool) external onlyOwner {
        pools[_pool] = true;
    }

    /// @notice Register new pools in batch to the Blended Pool
    function addPools(address[] memory _pools) external onlyOwner {
        for (uint256 i = 0; i < _pools.length; i++) {
            pools[_pools[i]] = true;
        }
    }

    /// @notice Remove a pool when it's no longer actual
    function removePool(address _pool) external onlyOwner {
        pools[_pool] = false;
    }

    modifier onlyPool() {
        require(pools[msg.sender], "P:NOT_POOL");
        _;
    }
}
