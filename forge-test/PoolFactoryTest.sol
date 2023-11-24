pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {FixtureContract} from "./FixtureContract.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";

contract PoolFactoryTest is Test, FixtureContract {
    function setUp() public {
        fixture();
    }

    function test_governor_Pause() public {
        vm.startPrank(OWNER_ADDRESS);

        //Asserts if initial state of contract is paused
        assertEq(poolFactory.paused(), false);

        //Sets contract paused
        poolFactory.pause();

        //Asserts if after pausing contract paused
        assertEq(poolFactory.paused(), true);

        poolFactory.unpause();

        assertEq(poolFactory.paused(), false);

        vm.stopPrank();
    }

    function test_not_governor_Pause(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        //Asserts if initial state of contract is paused
        assertEq(poolFactory.paused(), false);

        //Sets contract paused
        vm.expectRevert(bytes("PF:NOT_GOV_OR_ADM"));
        poolFactory.pause();

        vm.stopPrank();
    }

    function test_governor_setGlobals() public {
        vm.startPrank(OWNER_ADDRESS);

        HeliosGlobals newGlobals = new HeliosGlobals(OWNER_ADDRESS, ADMIN_ADDRESS);
        address newGlobalsAddress = address(newGlobals);

        assertNotEq(address(poolFactory.globals()), newGlobalsAddress);

        poolFactory.setGlobals(newGlobalsAddress);

        assertEq(address(poolFactory.globals()), newGlobalsAddress);

        vm.stopPrank();
    }

    function test_not_governor_setGlobals(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        HeliosGlobals newGlobals = new HeliosGlobals(OWNER_ADDRESS, ADMIN_ADDRESS);
        address newGlobalsAddress = address(newGlobals);

        assertNotEq(address(poolFactory.globals()), newGlobalsAddress);

        vm.expectRevert(bytes("PF:NOT_GOV"));
        poolFactory.setGlobals(newGlobalsAddress);
    }

//    function test_governor_setPoolFactoryAdmin(address user) public {
//        vm.assume(user != OWNER_ADDRESS);
//
//        vm.startPrank(OWNER_ADDRESS);
//
//        assertNotEq(poolFactory.poolFactoryAdmins(address(user)), false);
//
//        poolFactory.setPoolFactoryAdmin(address(user), true);
//
//        assertNotEq(poolFactory.poolFactoryAdmins(address(user)), true);
//
//        vm.stopPrank();
//    }
}
