pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";
import {PoolLibrary} from "../../contracts/library/PoolLibrary.sol";

contract PoolLibraryTest is Test, FixtureContract {
    using EnumerableSet for EnumerableSet.AddressSet;
    using PoolLibrary for PoolLibrary.DepositsStorage;

    PoolLibrary.DepositsStorage private depositsStorage;

    function setUp() public {
        fixture();
    }

    function testFuzz_get_holders_count(address user) public {
        vm.assume(user != address(0));

//        // Initial state
//        assertEq(depositsStorage.holders.length(), depositsStorage);

    }

    function testFuzz_add_deposit(address user, address anotherUser, uint256 amount) public {
        vm.assume(user != address(0));
        vm.assume(anotherUser != address(0));
        vm.assume(anotherUser != user);

        // Initial state
        assertEq(depositsStorage.holders.length(), 0);
        assertEq(depositsStorage.userDeposits[user].length, 0);

        // Add deposit for user
        depositsStorage.addDeposit(user, amount, block.timestamp);
        assertEq(depositsStorage.holders.length(), 1);
        assertEq(depositsStorage.userDeposits[user].length, 1);

        // Add another deposit for user
        depositsStorage.addDeposit(user, amount, block.timestamp);
        assertEq(depositsStorage.holders.length(), 1);
        assertEq(depositsStorage.userDeposits[user].length, 2);

        // Add deposit for anotherUser
        assertEq(depositsStorage.userDeposits[anotherUser].length, 0);
        depositsStorage.addDeposit(anotherUser, amount, block.timestamp);
        assertEq(depositsStorage.holders.length(), 2);
        assertEq(depositsStorage.userDeposits[anotherUser].length, 1);

        vm.stopPrank();
    }

//    function testFuzz_delete_deposit(address pool, address notPool, address holder, uint256 amount) public {
//        vm.assume(pool != address(0));
//        vm.assume(notPool != address(0));
//        vm.assume(pool != notPool);
//        vm.assume(holder != address(0));
//
//        vm.startPrank(pool, pool);
//        DepositsHolder depositsHolder = new DepositsHolder(pool);
//        depositsHolder.addDeposit(holder, amount, block.timestamp);
//        depositsHolder.addDeposit(holder, amount, block.timestamp);
//
//        depositsHolder.deleteDeposit(holder, 0);
//        depositsHolder.deleteDeposit(holder, 0);
//
//        vm.expectRevert(bytes("DH:INVALID_INDEX"));
//        depositsHolder.deleteDeposit(holder, 0);
//
//        assertEq(depositsHolder.getHoldersCount(), 1);
//        PoolLibrary.DepositInstance[] memory depositsAfter = depositsHolder.getDepositsByHolder(holder);
//        assertEq(depositsAfter.length, 0);
//
//        depositsHolder.addDeposit(holder, amount, block.timestamp);
//        vm.stopPrank();
//
//        vm.startPrank(notPool, notPool);
//        vm.expectRevert(bytes("DH:NOT_POOL"));
//        depositsHolder.deleteDeposit(holder, 0);
//        vm.stopPrank();
//    }

    function testFuzz_get_holder(address pool, address holder, address nonHolder, uint256 amount) public {
        vm.assume(pool != address(0));
        vm.assume(holder != address(0));
        vm.assume(holder != nonHolder);

//        vm.startPrank(pool, pool);
//        // Initial state
//        assertEq(depositsHolder.getHoldersCount(), 0);
//
//        vm.expectRevert(bytes("DH:INVALID_INDEX"));
//        depositsHolder.getHolderByIndex(0);
//
//        // Add deposit for holder
//        depositsHolder.addDeposit(holder, amount, block.timestamp);
//        assertEq(depositsHolder.getHoldersCount(), 1);
//        PoolLibrary.DepositInstance[] memory holdersDeposits = depositsHolder.getDepositsByHolder(holder);
//        assertEq(holdersDeposits.length, 1);
//
//        vm.expectRevert(bytes("DH:INVALID_HOLDER"));
//        depositsHolder.getDepositsByHolder(nonHolder);
//
//        vm.expectRevert(bytes("DH:INVALID_INDEX"));
//        depositsHolder.getHolderByIndex(5);

        vm.stopPrank();
    }
}
