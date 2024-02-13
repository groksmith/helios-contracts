pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";
import {HeliosGlobals} from "../../contracts/global/HeliosGlobals.sol";

contract PoolFactoryTest is Test, FixtureContract {
    function setUp() public {
        fixture();
    }

    function test_Pause() public {
        vm.startPrank(OWNER_ADDRESS);

        //Asserts if initial state of contract is paused
        assertEq(heliosGlobals.protocolPaused(), false);

        poolFactory.createPool(
            "1",
            address(asset),
            2000,
            10,
            1000,
            100000,
            100,
            500,
            1000
        );

        heliosGlobals.setProtocolPause(true);

        //Asserts if after pausing contract paused
        assertEq(heliosGlobals.protocolPaused(), true);

        vm.expectRevert(bytes("P:PROTO_PAUSED"));
        poolFactory.createPool(
            "2",
            address(asset),
            2000,
            10,
            1000,
            100000,
            100,
            500,
            1000
        );

        vm.expectRevert(bytes("P:PROTO_PAUSED"));
        poolFactory.createBlendedPool(
            address(asset),
            10,
            1000,
            100000,
            100,
            500,
            1000
        );

        vm.stopPrank();
    }

    function test_admin_setGlobals() public {
        vm.startPrank(OWNER_ADDRESS);

        HeliosGlobals newGlobals = new HeliosGlobals(OWNER_ADDRESS);
        address newGlobalsAddress = address(newGlobals);

        assertNotEq(address(poolFactory.globals()), newGlobalsAddress);

        poolFactory.setGlobals(newGlobalsAddress);

        assertEq(address(poolFactory.globals()), newGlobalsAddress);

        vm.expectRevert(bytes("PF:ZERO_NEW_GLOBALS"));
        poolFactory.setGlobals(address(0));

        vm.stopPrank();
    }

    function testFuzz_not_admin_setGlobals(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        HeliosGlobals newGlobals = new HeliosGlobals(OWNER_ADDRESS);
        address newGlobalsAddress = address(newGlobals);

        assertNotEq(address(poolFactory.globals()), newGlobalsAddress);

        vm.expectRevert(bytes("PF:NOT_ADMIN"));
        poolFactory.setGlobals(newGlobalsAddress);
    }

    function test_pool_already_exists() public {
        vm.startPrank(OWNER_ADDRESS);

        poolFactory.createPool(
            "1",
            address(asset),
            2000,
            10,
            1000,
            100000,
            100,
            500,
            1000
        );

        vm.expectRevert(bytes("PF:POOL_ID_ALREADY_EXISTS"));
        poolFactory.createPool(
            "1",
            address(asset),
            2000,
            10,
            1000,
            100000,
            100,
            500,
            1000
        );

        vm.stopPrank();
    }

    function test_blended_pool_already_exists() public {
        vm.startPrank(OWNER_ADDRESS);

        // Already created in parent FixtureContract
        vm.expectRevert(bytes("PF:BLENDED_POOL_ALREADY_CREATED"));
        poolFactory.createBlendedPool(
            address(asset),
            10,
            1000,
            100000,
            100,
            500,
            1000
        );

        vm.stopPrank();
    }

    function testFuzz_pool_create(
        string calldata poolId,
        uint256 lockupPeriod,
        uint256 apy,
        uint256 duration,
        uint256 investmentPoolSize,
        uint256 minInvestmentAmount,
        uint256 withdrawThreshold,
        uint256 withdrawPeriod,
        address randomAddress
    ) public {
        vm.startPrank(OWNER_ADDRESS);

        address poolAddress = poolFactory.createPool(
            poolId,
            address(asset),
            lockupPeriod,
            apy,
            duration,
            investmentPoolSize,
            minInvestmentAmount,
            withdrawThreshold,
            withdrawPeriod
        );

        assertEq(poolFactory.isValidPool(poolAddress), true);

        vm.assume(randomAddress != poolAddress);
        assertEq(poolFactory.isValidPool(randomAddress), false);

        vm.stopPrank();
    }
}
