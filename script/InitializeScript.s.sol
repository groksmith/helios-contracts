// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {PoolFactory} from "../contracts/pool/PoolFactory.sol";
import {MockTokenERC20} from "../tests/mocks/MockTokenERC20.sol";

contract InitializeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address heliosGlobalsAddress = vm.envAddress("HELIOS_GLOBALS");
        address poolFactoryAddress = vm.envAddress("POOL_FACTORY");
        address heliosUsdAddress = vm.envAddress("HELIOS_USD");
        address usdcAddress = vm.envAddress("USDC");
        string memory tokenName = vm.envString("NAME");
        string memory tokenSymbol = vm.envString("SYMBOL");

        vm.startBroadcast(deployerPrivateKey);

        HeliosGlobals heliosGlobals = HeliosGlobals(heliosGlobalsAddress);
        heliosGlobals.setPoolFactory(poolFactoryAddress);
        heliosGlobals.setAsset(heliosUsdAddress, true);
        heliosGlobals.setAsset(usdcAddress, true);

        PoolFactory poolFactory = PoolFactory(poolFactoryAddress);
        address blendedPoolAddress = poolFactory.createBlendedPool(
            {
                _asset: usdcAddress,
                _lockupPeriod: 86400,
                _minInvestmentAmount: 100000000,
                _tokenName: tokenName,
                _tokenSymbol: tokenSymbol
            }
        );

        console.log("BlendedPool address: %s", blendedPoolAddress);

        vm.stopBroadcast();
    }
}