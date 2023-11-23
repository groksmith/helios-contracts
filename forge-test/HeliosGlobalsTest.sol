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

    function test_notOwnerSetPaused(address randomUser) public {
        vm.startPrank(randomUser);

        //Asserts if initial state of contract is paused
        assertEq(heliosGlobals.protocolPaused(), false);

        //Sets contract paused
        vm.expectRevert(bytes("HG:NOT_ADM"));
        heliosGlobals.setProtocolPause(true);

        //Asserts if after pausing contract it is not paused
        assertEq(heliosGlobals.protocolPaused(), false);

        vm.stopPrank();
    }

    function test_when_owner_setValidPoolFactory() public {
        vm.startPrank(OWNER_ADDRESS);

        heliosGlobals.setValidPoolFactory(POOL_FACTORY_ADDRESS, true);

        assertEq(heliosGlobals.isValidPoolFactory(POOL_FACTORY_ADDRESS), true);
        assertEq(heliosGlobals.isValidPoolFactory(address(1)), false);

        vm.stopPrank();
    }

    function test_when_not_owner_setValidPoolFactory() public {
        vm.startPrank(address(1));

        vm.expectRevert(bytes("MG:NOT_GOV"));
        heliosGlobals.setValidPoolFactory(POOL_FACTORY_ADDRESS, true);

        assertEq(heliosGlobals.isValidPoolFactory(POOL_FACTORY_ADDRESS), false);

        vm.stopPrank();
    }

    function test_when_owner_setPoolDelegateAllowList() public {
        vm.startPrank(OWNER_ADDRESS);

        address poolDelegate = address(0);
        heliosGlobals.setPoolDelegateAllowList(poolDelegate, true);

        assertEq(heliosGlobals.isValidPoolDelegate(poolDelegate), true);
        assertEq(heliosGlobals.isValidPoolDelegate(address(1)), false);

        vm.stopPrank();
    }

    function test_when_not_owner_setPoolDelegateAllowList() public {
        vm.startPrank(address(1));
        address poolDelegate = address(0);

        vm.expectRevert(bytes("MG:NOT_GOV"));
        heliosGlobals.setPoolDelegateAllowList(poolDelegate, true);

        assertEq(heliosGlobals.isValidPoolDelegate(poolDelegate), false);

        vm.stopPrank();
    }

    function test_when_owner_setGlobalAdmin() public {
        address globalAdmin = address(1);

        assertNotEq(heliosGlobals.globalAdmin(), globalAdmin);

        vm.startPrank(OWNER_ADDRESS);
        heliosGlobals.setGlobalAdmin(globalAdmin);
        vm.stopPrank();

        assertEq(heliosGlobals.globalAdmin(), globalAdmin);
    }

    function test_when_paused_setGlobalAdmin() public {
        address globalAdmin = address(1);

        vm.startPrank(ADMIN_ADDRESS);
        heliosGlobals.setProtocolPause(true);
        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS);
        vm.expectRevert(bytes("HG:PROTO_PAUSED"));
        heliosGlobals.setGlobalAdmin(globalAdmin);
        vm.stopPrank();

        vm.startPrank(ADMIN_ADDRESS);
        heliosGlobals.setProtocolPause(false);
        vm.stopPrank();
    }

    function test_when_not_owner_setGlobalAdmin(address user) public {
        address globalAdmin = address(1);

        assertNotEq(heliosGlobals.globalAdmin(), globalAdmin);

        vm.startPrank(user);
        vm.expectRevert(bytes("HG:NOT_GOV_OR_ADM"));
        heliosGlobals.setGlobalAdmin(globalAdmin);
        vm.stopPrank();

        assertNotEq(heliosGlobals.globalAdmin(), globalAdmin);
    }

}