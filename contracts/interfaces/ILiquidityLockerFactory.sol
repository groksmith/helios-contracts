// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "./ISubFactory.sol";

interface ILiquidityLockerFactory is ISubFactory {
    function newLocker(address liquidityAsset) external returns (address liquidityLocker);
}
