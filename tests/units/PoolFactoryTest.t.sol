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
            {
                _poolId: "1",
                _asset: address(asset),
                _lockupPeriod: 100000,
                _minInvestmentAmount: 100,
                _investmentPoolSize: 1000,
                _tokenName: NAME,
                _tokenSymbol: SYMBOL
            }
        );

        heliosGlobals.setProtocolPause(true);

        //Asserts if after pausing contract paused
        assertEq(heliosGlobals.protocolPaused(), true);

        vm.expectRevert(bytes("P:PROTO_PAUSED"));
        poolFactory.createPool(
            {
                _poolId: "2",
                _asset: address(asset),
                _lockupPeriod: 100000,
                _minInvestmentAmount: 100,
                _investmentPoolSize: 1000,
                _tokenName: NAME,
                _tokenSymbol: SYMBOL
            }
        );

        vm.expectRevert(bytes("P:PROTO_PAUSED"));
        poolFactory.createBlendedPool(
            {
                _asset: address(asset),
                _lockupPeriod: 100000,
                _minInvestmentAmount: 100,
                _tokenName: NAME,
                _tokenSymbol: SYMBOL
            }
        );

        vm.stopPrank();
    }

    function test_pool_already_exists() public {
        vm.startPrank(OWNER_ADDRESS);

        poolFactory.createPool(
            {
                _poolId: "1",
                _asset: address(asset),
                _lockupPeriod: 100000,
                _minInvestmentAmount: 100,
                _investmentPoolSize: 1000,
                _tokenName: NAME,
                _tokenSymbol: SYMBOL
            }
        );

        vm.expectRevert(bytes("PF:POOL_ID_ALREADY_EXISTS"));
        poolFactory.createPool(
            {
                _poolId: "1",
                _asset: address(asset),
                _lockupPeriod: 100000,
                _minInvestmentAmount: 100,
                _investmentPoolSize: 1000,
                _tokenName: NAME,
                _tokenSymbol: SYMBOL
            }
        );

        vm.stopPrank();
    }

    function test_blended_pool_already_exists() public {
        vm.startPrank(OWNER_ADDRESS);

        // Already created in parent FixtureContract
        vm.expectRevert(bytes("PF:BLENDED_POOL_ALREADY_CREATED"));
        poolFactory.createBlendedPool(
            {
                _asset: address(asset),
                _lockupPeriod: 100000,
                _minInvestmentAmount: 100,
                _tokenName: NAME,
                _tokenSymbol: SYMBOL
            }
        );

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
            {
                _poolId: poolId,
                _asset: address(asset),
                _lockupPeriod: lockupPeriod,
                _minInvestmentAmount: minInvestmentAmount,
                _investmentPoolSize: investmentPoolSize,
                _tokenName: NAME,
                _tokenSymbol: SYMBOL
            }
        );

        vm.assume(randomAddress != poolAddress);
        vm.assume(randomAddress != address(regPool1));

        assertEq(poolFactory.isValidPool(poolAddress), true);
        assertEq(poolFactory.isValidPool(randomAddress), false);

        vm.stopPrank();
    }
}
