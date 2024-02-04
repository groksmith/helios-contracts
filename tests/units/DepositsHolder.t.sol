pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";
import {DepositsHolder} from "../../contracts/pool/DepositsHolder.sol";
import {DepositInstance} from "../../contracts/pool/DepositsHolder.sol";

contract DepositsHolderTest is Test, FixtureContract {
    DepositsHolder public depositsHolder;

    function setUp() public {
        fixture();
        depositsHolder = new DepositsHolder();
    }

    function testFuzz_add_deposit(address user, uint256 amount) public {
        vm.assume(user != address(0));

        vm.startPrank(user, user);
        assertEq(depositsHolder.getHoldersCount(), 0);
        depositsHolder.addDeposit(user, liquidityAsset, amount, vm.getBlockTimestamp());

        assertEq(depositsHolder.getHoldersCount(), 1);
        DepositInstance[] memory depositsFirst = depositsHolder.getDepositsByHolder(user);
        assertEq(depositsFirst.length, 1);

        depositsHolder.addDeposit(user, liquidityAsset, amount, vm.getBlockTimestamp());

        assertEq(depositsHolder.getHoldersCount(), 1);
        DepositInstance[] memory depositsSecond = depositsHolder.getDepositsByHolder(user);
        assertEq(depositsSecond.length, 2);

        vm.stopPrank();
    }

    function testFuzz_delete_deposit(address holder, uint256 amount) public {
        vm.assume(holder != address(0));

        vm.startPrank(holder, holder);
        depositsHolder.addDeposit(holder, liquidityAsset, amount, vm.getBlockTimestamp());
        depositsHolder.addDeposit(holder, liquidityAsset, amount, vm.getBlockTimestamp());

        depositsHolder.deleteDeposit(holder, 0);
        depositsHolder.deleteDeposit(holder, 0);

        vm.expectRevert(bytes("DH:INVALID_INDEX"));
        depositsHolder.deleteDeposit(holder, 0);

        assertEq(depositsHolder.getHoldersCount(), 1);
        DepositInstance[] memory depositsAfter = depositsHolder.getDepositsByHolder(holder);
        assertEq(depositsAfter.length, 0);

        vm.stopPrank();
    }

    function testFuzz_get_holder(address holder, address nonHolder, uint256 amount) public {
        vm.assume(holder != address(0));
        vm.assume(holder != nonHolder);

        vm.startPrank(holder, holder);

        // Initial state
        assertEq(depositsHolder.getHoldersCount(), 0);

        vm.expectRevert(bytes("DH:INVALID_INDEX"));
        depositsHolder.getHolderByIndex(0);

        vm.expectRevert(bytes("DH:INVALID_HOLDER"));
        depositsHolder.getDepositsByHolder(holder);

        // Add deposit for holder
        depositsHolder.addDeposit(holder, liquidityAsset, amount, vm.getBlockTimestamp());
        assertEq(depositsHolder.getHoldersCount(), 1);
        DepositInstance[] memory holdersDeposits = depositsHolder.getDepositsByHolder(holder);
        assertEq(holdersDeposits.length, 1);

        vm.expectRevert(bytes("DH:INVALID_HOLDER"));
        depositsHolder.getDepositsByHolder(nonHolder);

        vm.expectRevert(bytes("DH:INVALID_INDEX"));
        depositsHolder.getHolderByIndex(5);

        vm.stopPrank();
    }
}
