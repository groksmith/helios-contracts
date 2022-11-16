// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IHeliosGlobals {
    function governor() external view returns (address);

    function protocolPaused() external view returns (bool);

    function isValidPoolDelegate(address) external view returns (bool);
}
