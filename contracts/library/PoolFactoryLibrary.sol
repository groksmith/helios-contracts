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
        uint256 _investmentPoolSize,
        string memory _tokenName,
        string memory _tokenSymbol
    ) external returns (address) {
        Pool pool = new Pool(_asset, _lockupPeriod, _minInvestmentAmount, _investmentPoolSize, _tokenName, _tokenSymbol);
        return address(pool);
    }
}
