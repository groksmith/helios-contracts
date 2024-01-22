// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IHeliosGlobals {
    function protocolPaused() external view returns (bool);

    function isAdmin(address account) external view returns (bool);

    function isValidPoolFactory(address poolFactory) external view returns (bool);

    function isValidLiquidityAsset(address asset) external view returns (bool);

    function validSubFactories(address superFactory, address subFactory) external view returns (bool);
}
