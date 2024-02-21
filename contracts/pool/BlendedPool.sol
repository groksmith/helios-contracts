// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AbstractPool} from "./AbstractPool.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";
import {Pool} from "./Pool.sol";

/// @title Blended Pool implementation
/// @author Tigran Arakelyan
contract BlendedPool is AbstractPool {
    event RegPoolRequested(address indexed regPool, uint256 amount);

    constructor(address _asset, uint256 _lockupPeriod, uint256 _minInvestmentAmount)
    AbstractPool(_asset, NAME, SYMBOL) {
        poolInfo = PoolInfo(_lockupPeriod, _minInvestmentAmount, type(uint256).max);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    /// @param _amount the amount of assets to be deposited
    function deposit(uint256 _amount) external override whenProtocolNotPaused nonReentrant {
        require(_amount > 0, "BP:ZERO_AMOUNT");
        _depositLogic(_amount, msg.sender);
    }

    /// @notice Only called by a RegPool when it doesn't have enough Assets
    /// @param _amountRequested the amount requested for compensation
    function requestAssets(uint256 _amountRequested) external nonReentrant onlyPool {
        require(_amountRequested > 0, "BP:INVALID_AMOUNT");
        require(totalBalance() >= _amountRequested, "BP:NOT_ENOUGH_ASSETS");

        Pool pool = Pool(msg.sender);
        bool success = asset.approve(address(pool), _amountRequested);

        if(success)
        {
            pool.blendedPoolDeposit(_amountRequested);
            emit RegPoolRequested(msg.sender, _amountRequested);
        }
    }

    /// @notice Only pool can call
    modifier onlyPool() {
        require(poolFactory.isValidPool(msg.sender), "P:NOT_POOL");
        _;
    }
}
