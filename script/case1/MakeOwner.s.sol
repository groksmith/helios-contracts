// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";

contract MakeOwnerScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address blendedPoolAddress = vm.envAddress("BLENDED_POOL");
        BlendedPool blended_pool = BlendedPool(blendedPoolAddress);

        address[] memory holders = vm.envAddress("HOLDERS", ",");

        vm.startBroadcast(deployerPrivateKey);

        for (uint i = 0; i < holders.length; ++i) {
            address holder = holders[i];

            bool holderExists = blended_pool.holderExists(holder);
            if (!holderExists)
            {
                blended_pool.approve(holder, 1);
                blended_pool.transfer(holder, 1);
                console.log("Holder fixed", holder);
            }
        }

        vm.stopBroadcast();
    }
}