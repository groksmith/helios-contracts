// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Pool} from "../../contracts/pool/Pool.sol";
import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";
import {PoolFactory} from "../../contracts/pool/PoolFactory.sol";

// Used for testing only
contract MockPoolFactory is PoolFactory {
    constructor(address _globals) PoolFactory(_globals) {}

    // Instantiates a Pool
    function createPool(
        string calldata poolId,
        address liquidityAsset,
        uint256 lockupPeriod,
        uint256 apy,
        uint256 duration,
        uint256 investmentPoolSize,
        uint256 minInvestmentAmount,
        uint256 withdrawThreshold,
        uint256 withdrawPeriod
    ) external override whenProtocolNotPaused nonReentrant returns (address poolAddress) {
        _isMappingKeyValid(poolId);

        Pool pool = new Pool(
            liquidityAsset,
            lockupPeriod,
            apy,
            duration,
            investmentPoolSize,
            minInvestmentAmount,
            withdrawThreshold,
            withdrawPeriod
        );

        poolAddress = address(pool);
        pools[poolId] = poolAddress;
        isPool[poolAddress] = true;

        emit PoolCreated(poolId, liquidityAsset, poolAddress, msg.sender);
    }

    function createBlendedPool(
        address liquidityAsset,
        uint256 lockupPeriod,
        uint256 apy,
        uint256 duration,
        uint256 minInvestmentAmount,
        uint256 withdrawThreshold,
        uint256 withdrawPeriod
    ) external override whenProtocolNotPaused nonReentrant returns (address poolAddress) {
        BlendedPool pool = new BlendedPool(
            liquidityAsset,
            lockupPeriod,
            apy,
            duration,
            minInvestmentAmount,
            withdrawThreshold,
            withdrawPeriod
        );

        poolAddress = address(pool);
        blendedPool = poolAddress;

        emit BlendedPoolCreated(liquidityAsset, blendedPool, msg.sender);
    }
}
