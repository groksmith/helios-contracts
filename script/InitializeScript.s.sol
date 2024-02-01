// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {PoolFactory} from "../contracts/pool/PoolFactory.sol";
import {LiquidityLockerFactory} from "../contracts/pool/LiquidityLockerFactory.sol";
import {MockTokenERC20} from "../forge-test/mocks/MockTokenERC20.sol";

contract InitializeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address heliosGlobalsAddress = vm.envAddress("HELIOS_GLOBALS_ADDRESS");
        address poolFactoryAddress = vm.envAddress("POOL_FACTORY_ADDRESS");
        address liquidityLockerAddress = vm.envAddress("LIQUIDITY_LOCKER_FACTORY_ADDRESS");
        address usdtAddress = vm.envAddress("USDT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        HeliosGlobals heliosGlobals = HeliosGlobals(heliosGlobalsAddress);
        heliosGlobals.setValidLiquidityLockerFactory(liquidityLockerAddress, true);
        heliosGlobals.setLiquidityAsset(usdtAddress, true);
        heliosGlobals.setValidPoolFactory(poolFactoryAddress, true);

        vm.stopBroadcast();
    }
}