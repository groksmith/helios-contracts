// @author Tigran Arakelyan
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

    function testFuzz_get_holders_count(address[100] calldata holders, uint256 amount) public {
        uint256 amountBounded = bound(amount, 1, type(uint256).max);

        // Initial state
        assertEq(depositsStorage.getHoldersCount(), 0);

        uint256 index;
        for (uint256 i = 0; i < holders.length; i++) {
            // Skip repetitions and empty addresses
            vm.assume(holders[i] != address(0));
            vm.assume(depositsStorage.holderExists(holders[i]) == false);
            index++;

            // Add deposits
            depositsStorage.addDeposit(holders[i], amountBounded, block.timestamp + 1000);
            assertEq(depositsStorage.holderExists(holders[i]), true);

            assertEq(depositsStorage.getHoldersCount(), index);
        }
    }

    function test_get_holders_by_index(address holder1, address holder2) public {
        vm.assume(holder1 != address(0));
        vm.assume(holder2 != address(0));
        vm.assume(holder1 != holder2);

        vm.expectRevert(bytes("PL:INVALID_INDEX"));
        depositsStorage.getHolderByIndex(0);

        uint256 lockTime = block.timestamp + 1000;

        // Add deposits
        depositsStorage.addDeposit(holder1, 100, lockTime);
        assertEq(depositsStorage.getHolderByIndex(0), holder1);

        depositsStorage.addDeposit(holder1, 100, lockTime);
        assertEq(depositsStorage.getHolderByIndex(0), holder1);

        depositsStorage.addDeposit(holder2, 200, lockTime);
        assertEq(depositsStorage.getHolderByIndex(1), holder2);

        vm.expectRevert(bytes("PL:INVALID_INDEX"));
        depositsStorage.getHolderByIndex(2);
    }

    function testFuzz_add_deposit(address holder, address anotherHolder, uint256 amount) public {
        vm.assume(holder != address(0));
        vm.assume(anotherHolder != address(0));
        vm.assume(anotherHolder != holder);

        uint256 amountBounded = bound(amount, 1, type(uint256).max / 4);
        uint256 lockTime = block.timestamp + 1000;

        // Initial state
        assertEq(depositsStorage.getHoldersCount(), 0);
        assertEq(depositsStorage.lockedDeposits[holder].length, 0);

        // check for overflow
        expectOverflow(holder, amountBounded);

        // Add deposit for user
        depositsStorage.addDeposit(holder, amountBounded, lockTime);

        assertEq(depositsStorage.getHoldersCount(), 1);
        assertEq(depositsStorage.lockedDeposits[holder].length, 1);

        // check for overflow
        expectOverflow(holder, amountBounded);

        // Add another deposit for user
        depositsStorage.addDeposit(holder, amountBounded, lockTime);
        assertEq(depositsStorage.getHoldersCount(), 1);
        assertEq(depositsStorage.lockedDeposits[holder].length, 2);

        // Add deposit for anotherUser
        assertEq(depositsStorage.lockedDeposits[anotherHolder].length, 0);

        // check for overflow
        expectOverflow(anotherHolder, amountBounded);
        depositsStorage.addDeposit(anotherHolder, amountBounded, lockTime);
        assertEq(depositsStorage.getHoldersCount(), 2);
        assertEq(depositsStorage.lockedDeposits[anotherHolder].length, 1);

        // Try add 0 holder
        vm.expectRevert(bytes("PL:INVALID_HOLDER"));
        depositsStorage.addDeposit(address(0), amountBounded, lockTime);

        // Try add 0 deposit
        vm.expectRevert(bytes("PL:ZERO_AMOUNT"));
        depositsStorage.addDeposit(holder, 0, lockTime);

        // Try add wrong lockTime
        vm.expectRevert(bytes("PL:WRONG_UNLOCK_TIME"));
        depositsStorage.addDeposit(holder, amountBounded, block.timestamp - 1);
    }

    function testFuzz_locked_deposits_amount(address holder, address anotherHolder, uint256 amount1, uint256 amount2) public {
        vm.assume(holder != address(0));
        vm.assume(anotherHolder != address(0));
        vm.assume(anotherHolder != holder);

        uint256 amountBounded1 = bound(amount1, 1, type(uint256).max / 4);
        uint256 amountBounded2 = bound(amount2, 1, type(uint256).max / 4);

        uint256 lockTime1 = block.timestamp + 1000;
        uint256 lockTime2 = lockTime1 + 6000;

        // check for overflow
        expectOverflow(holder, amountBounded1);

        depositsStorage.addDeposit(holder, amountBounded1, lockTime1);
        assertEq(depositsStorage.lockedDepositsAmount(holder), amountBounded1);

        depositsStorage.addDeposit(holder, amountBounded2, lockTime2);
        assertEq(depositsStorage.lockedDepositsAmount(holder), amountBounded1 + amountBounded2);

        vm.warp(lockTime1 + 5);
        assertEq(depositsStorage.lockedDepositsAmount(holder), amountBounded2);

        vm.warp(lockTime2 + 5);
        assertEq(depositsStorage.lockedDepositsAmount(holder), 0);

        // Try add wrong lockTime
        vm.expectRevert(bytes("PL:INVALID_HOLDER"));
        depositsStorage.lockedDepositsAmount(address(0));
    }

    function testFuzz_cleanup_deposit(address holder) public {
        vm.assume(holder != address(0));
        uint256 amount = 100;
        uint256 lockTime1 = block.timestamp + 1000;
        uint256 lockTime2 = lockTime1 + 6000;

        vm.warp(block.timestamp);

        depositsStorage.cleanupDepositsStorage(holder);
        assertEq(depositsStorage.lockedDeposits[holder].length, 0);

        depositsStorage.addDeposit(holder, amount, lockTime1);
        assertEq(depositsStorage.lockedDeposits[holder].length, 1);

        depositsStorage.addDeposit(holder, amount, lockTime2);
        assertEq(depositsStorage.lockedDeposits[holder].length, 2);

        depositsStorage.addDeposit(holder, amount, lockTime2);
        assertEq(depositsStorage.lockedDeposits[holder].length, 3);

        depositsStorage.addDeposit(holder, amount, lockTime2);
        depositsStorage.cleanupDepositsStorage(holder);
        assertEq(depositsStorage.lockedDeposits[holder].length, 4);

        // all above will be expired and cleaned up
        vm.warp(lockTime2 + 10);
        depositsStorage.cleanupDepositsStorage(holder);

        assertEq(depositsStorage.lockedDeposits[holder].length, 0);
    }

    function expectOverflow(address holder, uint256 amount) public {
        if (depositsStorage.holderExists(holder))
        {
            if (type(uint256).max - depositsStorage.lockedDepositsAmount(holder) < amount)
            {
                vm.expectRevert(stdError.arithmeticError);
            }
        }
    }
}
