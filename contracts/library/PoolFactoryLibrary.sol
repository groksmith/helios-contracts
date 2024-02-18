// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pool} from "../pool/Pool.sol";

/// @title PoolFactoryLibrary
/// @author Tigran Arakelyan
library PoolFactoryLibrary {
    /// @notice Create Pool Instance
    function createPool(
        address _asset,
        uint256 _lockupPeriod,
        uint256 _minInvestmentAmount,
        uint256 _investmentPoolSize
    ) external returns (address) {
        Pool pool = new Pool(_asset, _lockupPeriod, _minInvestmentAmount, _investmentPoolSize);
        return address(pool);
    }
}
