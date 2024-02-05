// SPDX-License-Identifier: MIT
// @author Tigran Arakelyan
pragma solidity 0.8.20;

import {ISubFactory} from "./ISubFactory.sol";

interface ILiquidityLockerFactory is ISubFactory {
    function CreateLiquidityLocker(address liquidityAsset) external returns (address liquidityLocker);
}
