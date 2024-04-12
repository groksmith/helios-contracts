pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";
import {PoolLibrary} from "../../contracts/library/PoolLibrary.sol";
import {PoolLibraryErrors} from "../../contracts/library/PoolLibraryErrors.sol";

contract PoolLibraryTest is Test, FixtureContract, PoolLibraryErrors {
    using EnumerableSet for EnumerableSet.AddressSet;
    using PoolLibrary for PoolLibrary.Investments;

    PoolLibrary.Investments private investments;

    function setUp() public {
        fixture();
    }

    function testFuzz_get_holders_count(address[100] calldata holders, uint256 amount) public {
        uint256 amountBounded = bound(amount, 1, 1e24);

        // Initial state
        assertEq(investments.getHoldersCount(), 0);

        uint256 index;
        for (uint256 i = 0; i < holders.length; i++) {
            // Skip repetitions and empty addresses
            vm.assume(holders[i] != address(0));
            vm.assume(investments.holderExists(holders[i]) == false);
            index++;

            // Add deposits
            investments.addInvestment(holders[i], amountBounded, block.timestamp + 1000);
            assertEq(investments.holderExists(holders[i]), true);

            assertEq(investments.getHoldersCount(), index);
        }
    }

    function test_get_holders_by_index(address holder1, address holder2) public {
        vm.assume(holder1 != address(0));
        vm.assume(holder2 != address(0));
        vm.assume(holder1 != holder2);

        vm.expectRevert(InvalidIndex.selector);
        investments.getHolderByIndex(0);

        uint256 lockTime = block.timestamp + 1000;

        // Add deposits
        investments.addInvestment(holder1, 100, lockTime);
        assertEq(investments.getHolderByIndex(0), holder1);

        investments.addInvestment(holder1, 100, lockTime);
        assertEq(investments.getHolderByIndex(0), holder1);

        investments.addInvestment(holder2, 200, lockTime);
        assertEq(investments.getHolderByIndex(1), holder2);

        vm.expectRevert(InvalidIndex.selector);
        investments.getHolderByIndex(2);
    }

    function testFuzz_add_deposit(address holder, address anotherHolder, uint256 amount) public {
        vm.assume(holder != address(0));
        vm.assume(anotherHolder != address(0));
        vm.assume(anotherHolder != holder);

        uint256 amountBounded = bound(amount, 1, type(uint256).max / 4);
        uint256 lockTime = block.timestamp + 1000;

        // Initial state
        assertEq(investments.getHoldersCount(), 0);
        assertEq(investments.investmentRounds[holder].length, 0);

        // check for overflow
        expectOverflow(holder, amountBounded);

        // Add deposit for user
        investments.addInvestment(holder, amountBounded, lockTime);

        assertEq(investments.getHoldersCount(), 1);
        assertEq(investments.investmentRounds[holder].length, 1);

        // check for overflow
        expectOverflow(holder, amountBounded);

        // Add another deposit for user
        investments.addInvestment(holder, amountBounded, lockTime);
        assertEq(investments.getHoldersCount(), 1);
        assertEq(investments.investmentRounds[holder].length, 2);

        // Add deposit for anotherUser
        assertEq(investments.investmentRounds[anotherHolder].length, 0);

        // check for overflow
        expectOverflow(anotherHolder, amountBounded);
        investments.addInvestment(anotherHolder, amountBounded, lockTime);
        assertEq(investments.getHoldersCount(), 2);
        assertEq(investments.investmentRounds[anotherHolder].length, 1);

        // Try add 0 holder
        vm.expectRevert(InvalidHolder.selector);
        investments.addInvestment(address(0), amountBounded, lockTime);

        // Try add 0 deposit
        vm.expectRevert(ZeroAmount.selector);
        investments.addInvestment(holder, 0, lockTime);

        // Try add wrong lockTime
        vm.expectRevert(WrongUnlockTime.selector);
        investments.addInvestment(holder, amountBounded, block.timestamp - 1);
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

        investments.addInvestment(holder, amountBounded1, lockTime1);
        assertEq(investments.lockedInvestedAmount(holder), amountBounded1);

        investments.addInvestment(holder, amountBounded2, lockTime2);
        assertEq(investments.lockedInvestedAmount(holder), amountBounded1 + amountBounded2);

        vm.warp(lockTime1 + 5);
        assertEq(investments.lockedInvestedAmount(holder), amountBounded2);

        vm.warp(lockTime2 + 5);
        assertEq(investments.lockedInvestedAmount(holder), 0);

        // Try add wrong lockTime
        vm.expectRevert(InvalidHolder.selector);
        investments.lockedInvestedAmount(address(0));
    }

    function expectOverflow(address holder, uint256 amount) public {
        if (investments.holderExists(holder))
        {
            if (type(uint256).max - investments.lockedInvestedAmount(holder) < amount)
            {
                vm.expectRevert(stdError.arithmeticError);
            }
        }
    }
}
