// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {PoolFactory} from "../contracts/pool/PoolFactory.sol";
import {LiquidityLockerFactory} from "../contracts/pool/LiquidityLockerFactory.sol";
import {MockTokenERC20} from "../forge-test/mocks/MockTokenERC20.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address adminAddress = vm.envAddress("HELIOS_OWNER");

        vm.startBroadcast(deployerPrivateKey);

        HeliosGlobals heliosGlobals = new HeliosGlobals(adminAddress);
        new PoolFactory(address(heliosGlobals));
        new LiquidityLockerFactory();

        new MockTokenERC20("mUSDC", "mUSDC");

        vm.stopBroadcast();
    }
}