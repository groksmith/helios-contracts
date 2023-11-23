pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../contracts/global/HeliosGlobals.sol";
import {FixtureContract} from "./FixtureContract.sol";

contract HeliosGlobalsTest is Test, FixtureContract {
    HeliosGlobals public heliosGlobals;

    function setUp() public {
        heliosGlobals = new HeliosGlobals(OWNER_ADDRESS, ADMIN_ADDRESS);
    }

    function test_adminSetPaused() public {
        vm.startPrank(ADMIN_ADDRESS);

        //Asserts if initial state of contract is paused
        assertEq(heliosGlobals.protocolPaused(), false);

        //Sets contract paused
        heliosGlobals.setProtocolPause(true);

        //Asserts if after pausing contract paused
        assertEq(heliosGlobals.protocolPaused(), true);

        heliosGlobals.setProtocolPause(false);

        assertEq(heliosGlobals.protocolPaused(), false);

        vm.stopPrank();
    }

    function test_not_owner_setPaused(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        //Asserts if initial state of contract is paused
        assertEq(heliosGlobals.protocolPaused(), false);

        //Sets contract paused
        vm.expectRevert(bytes("HG:NOT_ADM"));
        heliosGlobals.setProtocolPause(true);

        //Asserts if after pausing contract it is not paused
        assertEq(heliosGlobals.protocolPaused(), false);

        vm.stopPrank();
    }

    function test_when_owner_setValidPoolFactory(address poolFactory) public {
        vm.assume(poolFactory != POOL_FACTORY_ADDRESS);
        vm.startPrank(OWNER_ADDRESS);

        heliosGlobals.setValidPoolFactory(POOL_FACTORY_ADDRESS, true);

        assertEq(heliosGlobals.isValidPoolFactory(POOL_FACTORY_ADDRESS), true);
        assertEq(heliosGlobals.isValidPoolFactory(poolFactory), false);

        vm.stopPrank();
    }

    function test_when_not_owner_setValidPoolFactory(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        vm.expectRevert(bytes("MG:NOT_GOV"));
        heliosGlobals.setValidPoolFactory(POOL_FACTORY_ADDRESS, true);

        assertEq(heliosGlobals.isValidPoolFactory(POOL_FACTORY_ADDRESS), false);

        vm.stopPrank();
    }
//
//    function test_when_owner_setPoolDelegateAllowList(address poolDelegate) public {
//        vm.startPrank(OWNER_ADDRESS);
//
//        assertEq(heliosGlobals.isValidPoolDelegate(poolDelegate), false);
//        heliosGlobals.setPoolDelegateAllowList(poolDelegate, true);
//        assertEq(heliosGlobals.isValidPoolDelegate(poolDelegate), true);
//
//        vm.stopPrank();
//    }
//
//    function test_when_not_owner_setPoolDelegateAllowList(address user, address poolDelegate) public {
//        vm.startPrank(user);
//
//        vm.expectRevert(bytes("MG:NOT_GOV"));
//        heliosGlobals.setPoolDelegateAllowList(poolDelegate, true);
//
//        assertEq(heliosGlobals.isValidPoolDelegate(poolDelegate), false);
//
//        vm.stopPrank();
//    }
//
//    function test_when_owner_setGlobalAdmin(address newAdmin) public {
//        assertNotEq(heliosGlobals.globalAdmin(), newAdmin);
//
//        vm.startPrank(OWNER_ADDRESS);
//        heliosGlobals.setGlobalAdmin(newAdmin);
//        vm.stopPrank();
//
//        assertEq(heliosGlobals.globalAdmin(), newAdmin);
//    }
//
//    function test_when_paused_setGlobalAdmin(address newAdmin) public {
//
//        vm.startPrank(ADMIN_ADDRESS);
//        heliosGlobals.setProtocolPause(true);
//        vm.stopPrank();
//
//        vm.startPrank(OWNER_ADDRESS);
//        vm.expectRevert(bytes("HG:PROTO_PAUSED"));
//        heliosGlobals.setGlobalAdmin(newAdmin);
//        vm.stopPrank();
//
//        vm.startPrank(ADMIN_ADDRESS);
//        heliosGlobals.setProtocolPause(false);
//        vm.stopPrank();
//    }
//
//    function test_when_not_owner_setGlobalAdmin(address user, address globalAdmin) public {
//        assertNotEq(heliosGlobals.globalAdmin(), globalAdmin);
//
//        vm.startPrank(user);
//        vm.expectRevert(bytes("HG:NOT_GOV_OR_ADM"));
//        heliosGlobals.setGlobalAdmin(globalAdmin);
//        vm.stopPrank();
//
//        assertNotEq(heliosGlobals.globalAdmin(), globalAdmin);
//    }
//
//    function test_when_owner_setLiquidityAsset(address liquidityAsset) public {
//        vm.startPrank(OWNER_ADDRESS);
//
//        heliosGlobals.setLiquidityAsset(LIQUIDITY_ASSET_ADDRESS, true);
//
//        assertEq(heliosGlobals.isValidLiquidityAsset(LIQUIDITY_ASSET_ADDRESS), true);
//        assertEq(heliosGlobals.isValidLiquidityAsset(liquidityAsset), false);
//
//        vm.stopPrank();
//    }

//    function test_when_not_owner_setLiquidityAsset() public {
//        vm.startPrank(address(1));
//
//        vm.expectRevert(bytes("MG:NOT_GOV"));
//        heliosGlobals.setLiquidityAsset(LIQUIDITY_ASSET_ADDRESS, true);
//
//        assertEq(heliosGlobals.isValidLiquidityAsset(LIQUIDITY_ASSET_ADDRESS), false);
//
//        vm.stopPrank();
//    }
}