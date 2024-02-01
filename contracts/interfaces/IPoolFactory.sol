// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IHeliosGlobals} from "./IHeliosGlobals.sol";

interface IPoolFactory {
    function globals() external view returns (IHeliosGlobals);
}
