// SPDX-License-Identifier: MIT
// @author Tigran Arakelyan
pragma solidity 0.8.20;

import {AbstractPool} from "./AbstractPool.sol";
import {BlendedPool} from "./BlendedPool.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";

// Pool maintains all accounting and functionality related to Pools
contract Pool is AbstractPool {
    enum State {Initialized, Finalized, Deactivated}
    State public poolState;

    event PoolStateChanged(State state);

    constructor(
        address _asset,
        uint256 _lockupPeriod,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_asset, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        poolInfo = PoolLibrary.PoolInfo(
            _lockupPeriod,
            _duration,
            _investmentPoolSize,
            _minInvestmentAmount,
            _withdrawThreshold);

        poolState = State.Initialized;
        emit PoolStateChanged(poolState);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external override whenProtocolNotPaused nonReentrant inState(State.Initialized) {
        require(totalSupply() + _amount <= poolInfo.investmentPoolSize, "P:MAX_POOL_SIZE_REACHED");

        _depositLogic(_amount);
    }

    /*
    Admin flow
    */

    // Finalize pool, disable new deposits
    function finalize() external onlyAdmin inState(State.Initialized) {
        poolState = State.Finalized;
        emit PoolStateChanged(poolState);
    }

    // Triggers deactivation, permanently shutting down the Pool. Only Admin can call this function
    function deactivate() external onlyAdmin inState(State.Finalized) {
        poolState = State.Deactivated;
        emit PoolStateChanged(poolState);
    }

    modifier inState(State _state) {
        require(poolState == _state, "P:BAD_STATE");
        _;
    }
}
