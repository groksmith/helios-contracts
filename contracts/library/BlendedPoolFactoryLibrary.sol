// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BlendedPool} from "../pool/BlendedPool.sol";

/// @title BlendedPoolFactoryLibrary
/// @author Tigran Arakelyan
library BlendedPoolFactoryLibrary {

    /// @notice Create BlendedPool Instance
    function createBlendedPool(
        address _asset,
        uint256 _lockupPeriod,
        uint256 _minInvestmentAmount,
        string memory _tokenName,
        string memory _tokenSymbol)
    external returns (address) {
        BlendedPool blendedPool = new BlendedPool(_asset, _lockupPeriod, _minInvestmentAmount, _tokenName, _tokenSymbol);
        return address(blendedPool);
    }
}
