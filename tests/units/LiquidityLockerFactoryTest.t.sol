pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";
import {HeliosGlobals} from "../../contracts/global/HeliosGlobals.sol";

contract LiquidityLockerFactoryTest is Test, FixtureContract {
    function setUp() public {
        fixture();
    }

    function testFuzz_create_liquidity_locker(address liquidityAsset) public {
        vm.assume(liquidityAsset != address(0));
        vm.prank(address(regPool1));
        liquidityLockerFactory.CreateLiquidityLocker(liquidityAsset);
    }

    function test_not_create_zero_liquidity_locker() public {
        vm.prank(OWNER_ADDRESS);
        vm.expectRevert("LL:ZERO_LIQ_ASSET");
        liquidityLockerFactory.CreateLiquidityLocker(address(0));
    }

    function test_factoryType() public {
        // LIQ_LOCKER_FACTORY = 1;
        assertEq(liquidityLockerFactory.factoryType(), 1);
    }
}
