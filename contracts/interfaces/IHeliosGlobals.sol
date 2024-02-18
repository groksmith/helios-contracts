// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IHeliosGlobals {
    function protocolPaused() external view returns (bool);

    function isAdmin(address account) external view returns (bool);

    function poolFactory() external view returns (address);

    function isValidAsset(address asset) external view returns (bool);
}
