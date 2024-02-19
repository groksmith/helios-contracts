pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";

contract HeliosGlobalsTest is Test, FixtureContract {
    event ProtocolPaused(bool pause);
    event GlobalAdminSet(address indexed newGlobalAdmin);
    event PoolFactorySet(address indexed poolFactory);
    event AssetSet(address asset, uint256 decimals, string symbol, bool valid);

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

    function test_when_owner_set_pool_factory() public {
        vm.startPrank(OWNER_ADDRESS);

        address poolFactoryAddress = address(poolFactory);

        vm.expectEmit();
        emit PoolFactorySet(poolFactoryAddress);

        heliosGlobals.setPoolFactory(poolFactoryAddress);
        assertEq(heliosGlobals.poolFactory(), poolFactoryAddress);

        vm.stopPrank();
    }

    function test_when_set_pool_factory_zero(address user) public {
        vm.startPrank(OWNER_ADDRESS);
        vm.expectRevert(bytes("HG:ZERO_POOL_FACTORY"));
        heliosGlobals.setPoolFactory(address(0));
        vm.stopPrank();
    }

    function testFuzz_when_not_owner_set_pool_factory(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);
        address poolFactoryAddress = address(poolFactory);
        vm.expectRevert(bytes("HG:NOT_ADMIN"));
        heliosGlobals.setPoolFactory(poolFactoryAddress);
        vm.stopPrank();
    }

    function test_when_owner_set_asset() public {
        vm.startPrank(OWNER_ADDRESS);
        address assetAddress = address(asset);

        vm.expectEmit();
        emit AssetSet(assetAddress, asset.decimals(), asset.symbol(), true);
        heliosGlobals.setAsset(assetAddress, true);
        assertEq(heliosGlobals.isValidAsset(assetAddress), true);
        vm.stopPrank();
    }

    function test_when_set_asset_zero() public {
        vm.startPrank(OWNER_ADDRESS);
        vm.expectRevert(bytes("HG:ZERO_ASSET"));
        heliosGlobals.setAsset(address(0), true);
        vm.stopPrank();
    }

    function testFuzz_when_not_owner_setAsset(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        address assetAddress = address(asset);
        vm.expectRevert(bytes("HG:NOT_ADMIN"));
        heliosGlobals.setAsset(assetAddress, true);

        vm.stopPrank();
    }
}
