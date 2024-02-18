// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BlendedPool} from "../pool/BlendedPool.sol";

/// @title BlendedPoolFactoryLibrary
/// @author Tigran Arakelyan
library BlendedPoolFactoryLibrary {
    /// @notice Create BlendedPool Instance
    function createBlendedPool(
        address asset,
        uint256 lockupPeriod,
        uint256 duration,
        uint256 minInvestmentAmount,
        uint256 withdrawThreshold,
        uint256 withdrawPeriod
    ) external returns (address) {
        BlendedPool blendedPool = new BlendedPool(
            asset,
            lockupPeriod,
            duration,
            minInvestmentAmount,
            withdrawThreshold,
            withdrawPeriod
        );
        return address(blendedPool);
    }
}
