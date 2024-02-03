// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AbstractPool} from "./AbstractPool.sol";
import {BlendedPool} from "./BlendedPool.sol";

// Pool maintains all accounting and functionality related to Pools
contract Pool is AbstractPool {
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
        poolInfo = PoolInfo(_lockupPeriod, _apy, _duration, _investmentPoolSize, _minInvestmentAmount, _withdrawThreshold);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external override whenProtocolNotPaused nonReentrant {
        require(totalSupply() + _amount <= poolInfo.investmentPoolSize, "P:MAX_POOL_SIZE_REACHED");

        _depositLogic(_amount, liquidityLocker.liquidityAsset());
    }

    /// @notice Used to transfer the investor's yield to him
    function withdrawYield() external override whenProtocolNotPaused returns (bool) {
        uint256 callerYields = yields[msg.sender];
        require(callerYields >= 0, "P:NOT_HOLDER");
        uint256 totalBalance = liquidityLockerTotalBalance();

        BlendedPool blendedPool = getBlendedPool();

        yields[msg.sender] = 0;

        if (totalBalance < callerYields) {
            uint256 amountMissing = callerYields - totalBalance;

            if (blendedPool.liquidityLockerTotalBalance() < amountMissing) {
                pendingYields[msg.sender] += callerYields;
                emit PendingYield(msg.sender, callerYields);
                return false;
            }
            blendedPool.requestLiquidityAssets(amountMissing);
            _mintAndUpdateTotalDeposited(address(blendedPool), amountMissing);

            require(_transferLiquidityLockerFunds(msg.sender, callerYields), "P:ERROR_TRANSFERRING_YIELD");

            emit YieldWithdrawn(msg.sender, callerYields);
            return true;
        }

        require(_transferLiquidityLockerFunds(msg.sender, callerYields), "P:ERROR_TRANSFERRING_YIELD");

        emit YieldWithdrawn(msg.sender, callerYields);
        return true;
    }

    /// @notice Used to distribute yields among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    /// @param  _holders the list of investors must be provided externally due to Solidity limitations
    function distributeYields(uint256 _amount, address[] calldata _holders) external override onlyAdmin nonReentrant {
        require(_amount > 0, "P:INVALID_VALUE");
        require(_holders.length > 0, "P:ZERO_HOLDERS");
        for (uint256 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];

            uint256 holderBalance = balanceOf(holder);
            uint256 holderShare = (holderBalance * 1e18) / poolInfo.investmentPoolSize;
            uint256 holderYields = holderShare * _amount / 1e18;
            yields[holder] += holderYields;
        }
    }

    function getBlendedPool() internal view returns (BlendedPool) {
        return BlendedPool(poolFactory.getBlendedPool());
    }
}
