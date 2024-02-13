// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AbstractPool} from "./AbstractPool.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";
import {Pool} from "./Pool.sol";

/// @title Blended Pool
contract BlendedPool is AbstractPool {
    event RegPoolDeposit(address indexed regPool, uint256 amount);

    constructor(
        address _asset,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_asset, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        poolInfo = PoolLibrary.PoolInfo(_lockupPeriod, _apy, _duration, type(uint256).max, _minInvestmentAmount, _withdrawThreshold);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external override whenProtocolNotPaused nonReentrant {
        _depositLogic(_amount, asset);
    }

    /// @notice Only called by a RegPool when it doesn't have enough Assets
    function requestAssets(uint256 _amountMissing) external onlyPool {
        require(_amountMissing > 0, "BP:INVALID_INPUT");
        require(totalBalance() >= _amountMissing, "BP:NOT_ENOUGH_LA_BP");
        require(_transferFunds(msg.sender, _amountMissing), "BP:REQUEST_FROM_BP_FAIL");

        emit RegPoolDeposit(msg.sender, _amountMissing);
    }

    function _calculateYield(address _holder, uint256 _amount) internal view override returns (uint256) {
        uint256 holderBalance = balanceOf(_holder);
        return (_amount * holderBalance) / totalSupply();
    }

    /*
    Modifiers
    */

    modifier onlyPool() {
        require(poolFactory.isValidPool(msg.sender), "P:NOT_POOL");
        _;
    }
}
