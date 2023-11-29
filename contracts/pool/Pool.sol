// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../interfaces/IPoolFactory.sol";
import "../interfaces/ILiquidityLockerFactory.sol";
import "../interfaces/ILiquidityLocker.sol";
import "../interfaces/IHeliosGlobals.sol";
import "../library/PoolLib.sol";
import "./AbstractPool.sol";
import "./BlendedPool.sol";

// Pool maintains all accounting and functionality related to Pools
contract Pool is AbstractPool {
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    address public immutable superFactory; // The factory that deployed this Pool
    address public immutable poolDelegate; // The Pool Delegate address, maintains full authority over the Pool
    BlendedPool public blendedPool;

    enum State {
        Initialized,
        Finalized,
        Deactivated
    }
    event PoolAdminSet(address indexed poolAdmin, bool allowed);
    mapping(address => bool) public poolAdmins; // The Pool Admin addresses that have permission to do certain operations in case of disaster management

    constructor(
        address _poolDelegate,
        address _liquidityAsset,
        address _llFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold
    ) AbstractPool(_liquidityAsset, _llFactory, PoolLib.NAME, PoolLib.SYMBOL) {
        require(_liquidityAsset != address(0), "P:ZERO_LIQ_ASSET");
        require(_poolDelegate != address(0), "P:ZERO_POOL_DLG");
        require(_llFactory != address(0), "P:ZERO_LIQ_LOCKER_FACTORY");
        poolInfo = PoolInfo(
            _lockupPeriod,
            _apy,
            _duration,
            _investmentPoolSize,
            _minInvestmentAmount,
            _withdrawThreshold
        );

        superFactory = msg.sender;
        poolDelegate = _poolDelegate;
    }

    /// @notice Used to transfer the investor's rewards to him
    function claimReward() external override returns (bool) {
        uint256 callerRewards = rewards[msg.sender];
        require(callerRewards >= 0, "P:NOT_HOLDER");
        uint256 totalBalance = liquidityLocker.totalBalance();
        rewards[msg.sender] = 0;

        if (totalBalance < callerRewards) {
            uint256 amountMissing = callerRewards - totalBalance;

            if (blendedPool.totalLA() < amountMissing) {
                pendingRewards[msg.sender] += callerRewards;
                emit PendingReward(msg.sender, callerRewards);
                return false;
            }
            blendedPool.requestLiquidityAssets(amountMissing);
            _mint(address(blendedPool), amountMissing);
            require(
                _transferLiquidityLockerFunds(msg.sender, callerRewards),
                "P:ERROR_TRANSFERRING_REWARD"
            );

            emit RewardClaimed(msg.sender, callerRewards);
            return true;
        }

        require(
            _transferLiquidityLockerFunds(msg.sender, callerRewards),
            "P:ERROR_TRANSFERRING_REWARD"
        );

        emit RewardClaimed(msg.sender, callerRewards);
        return true;
    }

    function canWithdraw(uint256 amount) external view returns (bool) {
        _canWithdraw(msg.sender, amount);
        return true;
    }

    function withdrawableOf(address _holder) external view returns (uint256) {
        require(
            depositDate[_holder].add(poolInfo.lockupPeriod) <= block.timestamp,
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

    //TODO to be deactivated
    function withdrawFunds() public override {
        _whenProtocolNotPaused();
        uint256 withdrawableFunds = _prepareWithdraw();

        if (withdrawableFunds == uint256(0)) return;

        _transferLiquidityLockerFunds(msg.sender, withdrawableFunds);
        _emitBalanceUpdatedEvent();

        interestSum = interestSum.sub(withdrawableFunds);

        _updateFundsTokenBalance();
    }

    //TODO to be deactivated
    function withdrawFundsAmount(uint256 amount) public override {
        _whenProtocolNotPaused();
        uint256 withdrawableFunds = _prepareWithdraw(amount);
        require(
            amount <= withdrawableFunds,
            "P:INSUFFICIENT_WITHDRAWABLE_FUNDS"
        );

        if (withdrawableFunds == uint256(0)) return;

        _transferLiquidityLockerFunds(msg.sender, amount);
        _emitBalanceUpdatedEvent();

        interestSum = interestSum.sub(amount);

        _updateFundsTokenBalance();
    }

    function setBlendedPool(address _blendedPool) external onlyOwner {
        blendedPool = BlendedPool(_blendedPool);
    }

    function _canWithdraw(address account, uint256 amount) internal view {
        require(
            depositDate[account].add(poolInfo.lockupPeriod) <= block.timestamp,
            "P:FUNDS_LOCKED"
        );
        require(balanceOf(account) >= amount, "P:INSUFFICIENT_BALANCE");
        require(
            amount <= _balanceOfLiquidityLocker(),
            "P:INSUFFICIENT_LIQUIDITY"
        );
    }

    // Get LiquidityLocker balance
    function _balanceOfLiquidityLocker() internal view returns (uint256) {
        return liquidityAsset.balanceOf(address(liquidityLocker));
    }

    // Checks that the protocol is not in a paused state
    function _whenProtocolNotPaused() internal view {
        require(!_globals(superFactory).protocolPaused(), "P:PROTO_PAUSED");
    }

    // Transfers Liquidity Asset to given `to` address
    function _transferLiquidityAssetFrom(
        address from,
        address to,
        uint256 value
    ) internal {
        liquidityAsset.safeTransferFrom(from, to, value);
    }

    // Returns the LiquidityLocker instance
    function _liquidityLocker() internal view returns (ILiquidityLocker) {
        return ILiquidityLocker(liquidityLocker);
    }

    // Returns the HeliosGlobals instance
    function _globals(
        address poolFactory
    ) internal view returns (IHeliosGlobals) {
        return IHeliosGlobals(IPoolFactory(poolFactory).globals());
    }
}
