// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pool} from "../pool/Pool.sol";

/// @title PoolFactoryLibrary
/// @author Tigran Arakelyan
library PoolFactoryLibrary {
    /// @notice Create Pool Instance
    function createPool(
        address asset,
        uint256 lockupPeriod,
        uint256 minInvestmentAmount,
        uint256 investmentPoolSize
    ) external returns (address) {
        Pool pool = new Pool(asset, lockupPeriod, minInvestmentAmount, investmentPoolSize);
        return address(pool);
    }
}
