// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ISubFactory} from "./ISubFactory.sol";

interface ILiquidityLockerFactory is ISubFactory {
    function newLocker(address liquidityAsset) external returns (address liquidityLocker);
}
