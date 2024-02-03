// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AbstractPool} from "./AbstractPool.sol";

/// @title Blended Pool
contract BlendedPool is AbstractPool {
    event RegPoolDeposit(address indexed regPool, uint256 amount);

    constructor(
        address _liquidityAsset,
        address _liquidityLockerFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_liquidityAsset, _liquidityLockerFactory, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        poolInfo = PoolInfo(_lockupPeriod, _apy, _duration, type(uint256).max, _minInvestmentAmount, _withdrawThreshold);
    }

    /// @notice Used to distribute rewards among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    /// @param  _holders the list of investors must be provided externally due to Solidity limitations
    function distributeRewards(uint256 _amount, address[] calldata _holders) external override onlyAdmin nonReentrant {
        require(_amount > 0, "BP:INVALID_VALUE");
        require(_holders.length > 0, "BP:ZERO_HOLDERS");
        for (uint256 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];

            uint256 holderBalance = balanceOf(holder);
            uint256 holderShare = (_amount * holderBalance) / totalSupply();
            rewards[holder] += holderShare;
        }
    }

    /// @notice Used to transfer the investor's rewards to him
    function claimReward() external override returns (bool) {
        uint256 callerRewards = rewards[msg.sender];
        uint256 totalBalance = liquidityLockerTotalBalance();
        rewards[msg.sender] = 0;

        if (totalBalance < callerRewards) {
            pendingRewards[msg.sender] += callerRewards;
            emit PendingReward(msg.sender, callerRewards);
            return false;
        }

        require(_transferLiquidityLockerFunds(msg.sender, callerRewards), "BP:ERROR_TRANSFERRING_REWARD");

        emit RewardClaimed(msg.sender, callerRewards);
        return true;
    }

    /// @notice Only called by a RegPool when it doesn't have enough Liquidity Assets
    function requestLiquidityAssets(uint256 _amountMissing) external onlyPool {
        require(_amountMissing > 0, "BP:INVALID_INPUT");
        require(liquidityLockerTotalBalance() >= _amountMissing, "BP:NOT_ENOUGH_LA_BP");
        address poolLiquidityLocker = AbstractPool(msg.sender).getLiquidityLocker();
        require(_transferLiquidityLockerFunds(poolLiquidityLocker, _amountMissing), "BP:REQUEST_FROM_BP_FAIL");

        emit RegPoolDeposit(msg.sender, _amountMissing);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external override whenProtocolNotPaused nonReentrant {
        _depositLogic(_amount, liquidityLocker.liquidityAsset());
    }

    /*
    Modifiers
    */

    modifier onlyPool() {
        require(poolFactory.isValidPool(msg.sender), "P:NOT_POOL");
        _;
    }
}
