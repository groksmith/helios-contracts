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
    function deposit(uint256 _amount) external override whenProtocolNotPaused nonReentrant {
        _depositLogic(_amount, msg.sender);
    }

    /// @notice Only called by a RegPool when it doesn't have enough Assets
    function requestAssets(uint256 _amountMissing) external onlyPool {
        require(_amountMissing > 0, "BP:INVALID_AMOUNT");
        require(totalBalance() >= _amountMissing, "BP:NOT_ENOUGH_ASSETS");

        Pool pool = Pool(msg.sender);
        asset.approve(address(pool), _amountMissing);
        pool.blendedPoolDeposit(_amountMissing);

        emit RegPoolRequested(msg.sender, _amountMissing);
    }

    /*
    Modifiers
    */

    /// @notice Only pool can call
    modifier onlyPool() {
        require(poolFactory.isValidPool(msg.sender), "P:NOT_POOL");
        _;
    }
}
