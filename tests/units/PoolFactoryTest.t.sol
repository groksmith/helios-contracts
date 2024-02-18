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
            100000,
            100,
            1000
        );

        heliosGlobals.setProtocolPause(true);

        //Asserts if after pausing contract paused
        assertEq(heliosGlobals.protocolPaused(), true);

        vm.expectRevert(bytes("P:PROTO_PAUSED"));
        poolFactory.createPool(
            "2",
            address(asset),
            100000,
            100,
            1000
        );

        vm.expectRevert(bytes("P:PROTO_PAUSED"));
        poolFactory.createBlendedPool(address(asset), 100000, 100);

        vm.stopPrank();
    }

    function test_pool_already_exists() public {
        vm.startPrank(OWNER_ADDRESS);

        poolFactory.createPool(
            "1",
            address(asset),
            100000,
            100,
            1000
        );

        vm.expectRevert(bytes("PF:POOL_ID_ALREADY_EXISTS"));
        poolFactory.createPool(
            "1",
            address(asset),
            100000,
            100,
            1000
        );

        vm.stopPrank();
    }

    function test_blended_pool_already_exists() public {
        vm.startPrank(OWNER_ADDRESS);

        // Already created in parent FixtureContract
        vm.expectRevert(bytes("PF:BLENDED_POOL_ALREADY_CREATED"));
        poolFactory.createBlendedPool(address(asset), 100000, 100);

        vm.stopPrank();
    }

    function testFuzz_pool_create(
        string calldata poolId,
        uint256 lockupPeriod,
        uint256 investmentPoolSize,
        uint256 minInvestmentAmount,
        address randomAddress
    ) public {
        vm.startPrank(OWNER_ADDRESS);

        address poolAddress = poolFactory.createPool(
            poolId,
            address(asset),
            lockupPeriod,
            minInvestmentAmount,
            investmentPoolSize
        );

        vm.assume(randomAddress != poolAddress);
        vm.assume(randomAddress != address(regPool1));
        
        assertEq(poolFactory.isValidPool(poolAddress), true);
        assertEq(poolFactory.isValidPool(randomAddress), false);

        vm.stopPrank();
    }
}
