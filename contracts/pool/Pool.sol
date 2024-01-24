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
import "./AbstractPool.sol";
import "./BlendedPool.sol";

// Pool maintains all accounting and functionality related to Pools
contract Pool is AbstractPool {
    using SafeERC20 for IERC20;

    address public immutable superFactory; // The factory that deployed this Pool
    BlendedPool public blendedPool;

    enum State {
        Initialized,
        Finalized,
        Deactivated
    }

    event PoolAdminSet(address indexed poolAdmin, bool allowed);

    mapping(address => bool) public poolAdmins; // The Pool Admin addresses that have permission to do certain operations in case of disaster management

    constructor(
        address _liquidityAsset,
        address _llFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_liquidityAsset, _llFactory, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        require(_liquidityAsset != address(0), "P:ZERO_LIQ_ASSET");
        require(_llFactory != address(0), "P:ZERO_LIQ_LOCKER_FACTORY");
        poolInfo =
            PoolInfo(_lockupPeriod, _apy, _duration, _investmentPoolSize, _minInvestmentAmount, _withdrawThreshold);

        superFactory = msg.sender;
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
            totalMinted += amountMissing;
            require(_transferLiquidityLockerFunds(msg.sender, callerRewards), "P:ERROR_TRANSFERRING_REWARD");

            emit RewardClaimed(msg.sender, callerRewards);
            return true;
        }

        require(_transferLiquidityLockerFunds(msg.sender, callerRewards), "P:ERROR_TRANSFERRING_REWARD");

        emit RewardClaimed(msg.sender, callerRewards);
        return true;
    }

    function canWithdraw(uint256 amount) external view returns (bool) {
        _canWithdraw(msg.sender, amount);
        return true;
    }

    function withdrawableOf(address _holder) external view returns (uint256) {
        require(depositDate[_holder] + poolInfo.lockupPeriod <= block.timestamp, "P:FUNDS_LOCKED");

        return Math.min(liquidityAsset.balanceOf(address(liquidityLocker)), super.balanceOf(_holder));
    }

    function totalDeposited() external view returns (uint256) {
        return totalMinted;
    }

    function decimals() public view override returns (uint8) {
        return uint8(liquidityAssetDecimals);
    }

    /// @notice Used to distribute rewards among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    /// @param  _holders the list of investors must be provided externally due to Solidity limitations
    function distributeRewards(uint256 _amount, address[] calldata _holders) external override onlyOwner nonReentrant {
        require(_amount > 0, "P:INVALID_VALUE");
        require(_holders.length > 0, "P:ZERO_HOLDERS");
        for (uint256 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];

            uint256 holderBalance = balanceOf(holder);
            uint256 holderShare = (holderBalance * 1e18) / poolInfo.investmentPoolSize;
            uint256 holderRewards = holderShare * _amount / 1e18;
            rewards[holder] += holderRewards;
        }
    }

    function setBlendedPool(address _blendedPool) external onlyOwner {
        blendedPool = BlendedPool(_blendedPool);
    }

    function _canWithdraw(address account, uint256 amount) internal view {
        require(depositDate[account] + poolInfo.lockupPeriod <= block.timestamp, "P:FUNDS_LOCKED");
        require(balanceOf(account) >= amount, "P:INSUFFICIENT_BALANCE");
        require(amount <= _balanceOfLiquidityLocker(), "P:INSUFFICIENT_LIQUIDITY");
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
    function _transferLiquidityAssetFrom(address from, address to, uint256 value) internal {
        liquidityAsset.safeTransferFrom(from, to, value);
    }

    // Returns the LiquidityLocker instance
    function _liquidityLocker() internal view returns (ILiquidityLocker) {
        return ILiquidityLocker(liquidityLocker);
    }

    // Returns the HeliosGlobals instance
    function _globals(address poolFactory) internal view returns (IHeliosGlobals) {
        return IHeliosGlobals(IPoolFactory(poolFactory).globals());
    }
}
