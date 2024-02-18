// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pool} from "../pool/Pool.sol";

/// @title PoolFactoryLibrary
/// @author Tigran Arakelyan
library PoolFactoryLibrary {
    /// @notice Create Pool Instance
    function createPool(
        string calldata poolId,
        address asset,
        uint256 lockupPeriod,
        uint256 investmentPoolSize,
        uint256 minInvestmentAmount,
        uint256 withdrawThreshold,
        uint256 withdrawPeriod
    ) external returns (address) {
        Pool pool = new Pool(
            asset,
            lockupPeriod,
            investmentPoolSize,
            minInvestmentAmount,
            withdrawThreshold,
            withdrawPeriod
        );
        return address(pool);
    }
}
