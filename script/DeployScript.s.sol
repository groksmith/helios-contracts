// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {PoolFactory} from "../contracts/pool/PoolFactory.sol";
import "../contracts/pool/LiquidityLockerFactory.sol";
import "../forge-test/mocks/MockTokenERC20.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address adminAddress = vm.envAddress("HELIOS_OWNER");

        vm.startBroadcast(deployerPrivateKey);

        HeliosGlobals heliosGlobals = new HeliosGlobals(adminAddress);
        PoolFactory poolFactory = new PoolFactory(address(heliosGlobals));
        LiquidityLockerFactory liquidityLockerFactory = new LiquidityLockerFactory();

        MockTokenERC20 liquidityAsset = new MockTokenERC20("mUSDC", "mUSDC");

        heliosGlobals.setValidLiquidityLockerFactory(address(liquidityLockerFactory), true);
        heliosGlobals.setLiquidityAsset(address(liquidityAsset), true);
        heliosGlobals.setValidPoolFactory(address(poolFactory), true);

        vm.stopBroadcast();
    }
}