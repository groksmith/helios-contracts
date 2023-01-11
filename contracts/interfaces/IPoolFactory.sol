// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IHeliosGlobals.sol";

interface IPoolFactory {
    function globals() external view returns (IHeliosGlobals);
}
