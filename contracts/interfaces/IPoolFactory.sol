// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IHeliosGlobals} from "./IHeliosGlobals.sol";

interface IPoolFactory {
    function globals() external view returns (IHeliosGlobals);

    function isValidPool(address) external view returns (bool);

    function getBlendedPool() external view returns (address);
}
