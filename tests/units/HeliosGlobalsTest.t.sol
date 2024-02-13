pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";

contract HeliosGlobalsTest is Test, FixtureContract {
    event ProtocolPaused(bool pause);
    event GlobalAdminSet(address indexed newGlobalAdmin);
    event LiquidityAssetSet(address asset, uint256 decimals, string symbol, bool valid);
    event ValidPoolFactorySet(address indexed poolFactory, bool valid);

    function setUp() public {
        fixture();
    }

    function test_adminSetPaused() public {
        vm.startPrank(OWNER_ADDRESS);

        //Asserts if initial state of contract is paused
        assertEq(heliosGlobals.protocolPaused(), false);

        vm.expectEmit();
        emit ProtocolPaused(true);
        //Sets contract paused
        heliosGlobals.setProtocolPause(true);

        //Asserts if after pausing contract paused
        assertEq(heliosGlobals.protocolPaused(), true);

        vm.expectEmit();
        emit ProtocolPaused(false);
        heliosGlobals.setProtocolPause(false);

        assertEq(heliosGlobals.protocolPaused(), false);

        vm.stopPrank();
    }

    function testFuzz_when_not_owner_setPaused(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        //Asserts if initial state of contract is paused
        assertEq(heliosGlobals.protocolPaused(), false);

        //Sets contract paused
        vm.expectRevert(bytes("HG:NOT_ADMIN"));
        heliosGlobals.setProtocolPause(true);

        //Asserts if after pausing contract it is not paused
        assertEq(heliosGlobals.protocolPaused(), false);

        vm.stopPrank();
    }

    function test_when_owner_setValidPoolFactory() public {
        vm.startPrank(OWNER_ADDRESS);

        address poolFactoryAddress = address(poolFactory);

        vm.expectEmit();
        emit ValidPoolFactorySet(poolFactoryAddress, true);

        heliosGlobals.setValidPoolFactory(poolFactoryAddress, true);
        assertEq(heliosGlobals.isValidPoolFactory(poolFactoryAddress), true);

        vm.stopPrank();
    }

    function testFuzz_when_not_owner_setValidPoolFactory(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        address poolFactoryAddress = address(poolFactory);
        vm.expectRevert(bytes("HG:NOT_ADMIN"));
        heliosGlobals.setValidPoolFactory(poolFactoryAddress, true);

        vm.stopPrank();
    }

    function test_when_owner_setLiquidityAsset() public {
        vm.startPrank(OWNER_ADDRESS);

        address liquidityAssetAddress = address(liquidityAsset);

        vm.expectEmit();
        emit LiquidityAssetSet(liquidityAssetAddress, liquidityAsset.decimals(), liquidityAsset.symbol(), true);

        heliosGlobals.setLiquidityAsset(liquidityAssetAddress, true);
        assertEq(heliosGlobals.isValidLiquidityAsset(liquidityAssetAddress), true);

        vm.stopPrank();
    }

    function testFuzz_when_not_owner_setLiquidityAsset(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        address liquidityAssetAddress = address(liquidityAsset);
        vm.expectRevert(bytes("HG:NOT_ADMIN"));
        heliosGlobals.setLiquidityAsset(liquidityAssetAddress, true);

        vm.stopPrank();
    }
}
