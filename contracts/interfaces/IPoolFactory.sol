// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IHeliosGlobals} from "./IHeliosGlobals.sol";

interface IPoolFactory {
    function globals() external view returns (IHeliosGlobals);
}
