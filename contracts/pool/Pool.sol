// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AbstractPool} from "./AbstractPool.sol";
import {BlendedPool} from "./BlendedPool.sol";

// Pool maintains all accounting and functionality related to Pools
contract Pool is AbstractPool {
    BlendedPool public blendedPool;

    constructor(
        address _liquidityAsset,
        address _liquidityLockerFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_liquidityAsset, _liquidityLockerFactory, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        poolInfo =
            PoolInfo(_lockupPeriod, _apy, _duration, _investmentPoolSize, _minInvestmentAmount, _withdrawThreshold);
    }

    /// @notice Used to transfer the investor's rewards to him
    function claimReward() external override whenProtocolNotPaused returns (bool) {
        uint256 callerRewards = rewards[msg.sender];
        require(callerRewards >= 0, "P:NOT_HOLDER");
        uint256 totalBalance = liquidityLockerTotalBalance();
        rewards[msg.sender] = 0;

        if (totalBalance < callerRewards) {
            uint256 amountMissing = callerRewards - totalBalance;

            if (blendedPool.liquidityLockerTotalBalance() < amountMissing) {
                pendingRewards[msg.sender] += callerRewards;
                emit PendingReward(msg.sender, callerRewards);
                return false;
            }
            blendedPool.requestLiquidityAssets(amountMissing);
            _mintAndUpdateTotalDeposited(address(blendedPool), amountMissing);

            require(_transferLiquidityLockerFunds(msg.sender, callerRewards), "P:ERROR_TRANSFERRING_REWARD");

            emit RewardClaimed(msg.sender, callerRewards);
            return true;
        }

        require(_transferLiquidityLockerFunds(msg.sender, callerRewards), "P:ERROR_TRANSFERRING_REWARD");

        emit RewardClaimed(msg.sender, callerRewards);
        return true;
    }

    /// @notice Used to distribute rewards among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    /// @param  _holders the list of investors must be provided externally due to Solidity limitations
    function distributeRewards(uint256 _amount, address[] calldata _holders) external override onlyAdmin nonReentrant {
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

    function setBlendedPool(address _blendedPool) external onlyAdmin {
        blendedPool = BlendedPool(_blendedPool);
    }
}
