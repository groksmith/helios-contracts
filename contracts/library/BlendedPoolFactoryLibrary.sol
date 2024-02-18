// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BlendedPool} from "../pool/BlendedPool.sol";

/// @title BlendedPoolFactoryLibrary
/// @author Tigran Arakelyan
library BlendedPoolFactoryLibrary {

    /// @notice Create BlendedPool Instance
    function createBlendedPool(address asset, uint256 lockupPeriod, uint256 minInvestmentAmount)
    external returns (address) {
        BlendedPool blendedPool = new BlendedPool(asset, lockupPeriod, minInvestmentAmount);
        return address(blendedPool);
    }
}
