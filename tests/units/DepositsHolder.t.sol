pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";
import {PoolLibrary} from "../../contracts/library/PoolLibrary.sol";
import {DepositsHolder} from "../../contracts/pool/DepositsHolder.sol";

contract DepositsHolderTest is Test, FixtureContract {
    function setUp() public {
        fixture();
    }

    function testFuzz_add_deposit(address user, uint256 amount) public {
        vm.assume(user != address(0));

        vm.startPrank(user, user);
        DepositsHolder depositsHolder = new DepositsHolder(user);

        assertEq(depositsHolder.getHoldersCount(), 0);
        depositsHolder.addDeposit(user, liquidityAsset, amount, vm.getBlockTimestamp());

        assertEq(depositsHolder.getHoldersCount(), 1);
        PoolLibrary.DepositInstance[] memory depositsFirst = depositsHolder.getDepositsByHolder(user);
        assertEq(depositsFirst.length, 1);

        depositsHolder.addDeposit(user, liquidityAsset, amount, vm.getBlockTimestamp());

        assertEq(depositsHolder.getHoldersCount(), 1);
        PoolLibrary.DepositInstance[] memory depositsSecond = depositsHolder.getDepositsByHolder(user);
        assertEq(depositsSecond.length, 2);

        vm.stopPrank();
    }

    function testFuzz_add_deposit_from_not_pool(address holder, address pool, address notPool) public {
        vm.assume(holder != address(0));
        vm.assume(pool != address(0));
        vm.assume(pool != holder);
        vm.assume(notPool != address(0));

        vm.startPrank(pool, pool);
        vm.expectRevert(bytes("DH:INVALID_POOL"));
        new DepositsHolder(address(0));
        vm.stopPrank();

        vm.startPrank(pool, pool);
        DepositsHolder depositsHolder = new DepositsHolder(pool);
        depositsHolder.addDeposit(holder, liquidityAsset, 100, vm.getBlockTimestamp());
        vm.stopPrank();

        vm.startPrank(notPool, notPool);
        vm.expectRevert(bytes("DH:NOT_POOL"));
        depositsHolder.addDeposit(holder, liquidityAsset, 100, vm.getBlockTimestamp());
        vm.stopPrank();
    }

    function testFuzz_delete_deposit(address holder, uint256 amount) public {
        vm.assume(holder != address(0));

        vm.startPrank(holder, holder);
        DepositsHolder depositsHolder = new DepositsHolder(holder);
        depositsHolder.addDeposit(holder, liquidityAsset, amount, vm.getBlockTimestamp());
        depositsHolder.addDeposit(holder, liquidityAsset, amount, vm.getBlockTimestamp());

        depositsHolder.deleteDeposit(holder, 0);
        depositsHolder.deleteDeposit(holder, 0);

        vm.expectRevert(bytes("DH:INVALID_INDEX"));
        depositsHolder.deleteDeposit(holder, 0);

        assertEq(depositsHolder.getHoldersCount(), 1);
        PoolLibrary.DepositInstance[] memory depositsAfter = depositsHolder.getDepositsByHolder(holder);
        assertEq(depositsAfter.length, 0);

        vm.stopPrank();
    }

    function testFuzz_get_holder(address holder, address nonHolder, uint256 amount) public {
        vm.assume(holder != address(0));
        vm.assume(holder != nonHolder);

        vm.startPrank(holder, holder);
        DepositsHolder depositsHolder = new DepositsHolder(holder);
        // Initial state
        assertEq(depositsHolder.getHoldersCount(), 0);

        vm.expectRevert(bytes("DH:INVALID_INDEX"));
        depositsHolder.getHolderByIndex(0);

        vm.expectRevert(bytes("DH:INVALID_HOLDER"));
        depositsHolder.getDepositsByHolder(holder);

        // Add deposit for holder
        depositsHolder.addDeposit(holder, liquidityAsset, amount, vm.getBlockTimestamp());
        assertEq(depositsHolder.getHoldersCount(), 1);
        PoolLibrary.DepositInstance[] memory holdersDeposits = depositsHolder.getDepositsByHolder(holder);
        assertEq(holdersDeposits.length, 1);

        vm.expectRevert(bytes("DH:INVALID_HOLDER"));
        depositsHolder.getDepositsByHolder(nonHolder);

        vm.expectRevert(bytes("DH:INVALID_INDEX"));
        depositsHolder.getHolderByIndex(5);

        vm.stopPrank();
    }
}
