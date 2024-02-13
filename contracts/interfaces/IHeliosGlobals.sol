// SPDX-License-Identifier: MIT
// @author Tigran Arakelyan
pragma solidity 0.8.20;

interface IHeliosGlobals {
    function protocolPaused() external view returns (bool);

    function isAdmin(address account) external view returns (bool);

    function isValidPoolFactory(address poolFactory) external view returns (bool);

    function isValidLiquidityAsset(address asset) external view returns (bool);
}
