// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {PoolFactory} from "../contracts/pool/PoolFactory.sol";
import {MockTokenERC20} from "../tests/mocks/MockTokenERC20.sol";

contract InitializeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address heliosGlobalsAddress = vm.envAddress("HELIOS_GLOBALS_ADDRESS");
        address poolFactoryAddress = vm.envAddress("POOL_FACTORY_ADDRESS");
        address usdtAddress = vm.envAddress("USDT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        HeliosGlobals heliosGlobals = HeliosGlobals(heliosGlobalsAddress);
        heliosGlobals.setPoolFactory(poolFactoryAddress);
        heliosGlobals.setAsset(usdtAddress, true);

        vm.stopBroadcast();
    }
}