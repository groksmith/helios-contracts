pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {MockTokenERC20} from "./mocks/MockTokenERC20.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {AbstractPool} from "../contracts/pool/AbstractPool.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import {BlendedPool} from "../contracts/pool/BlendedPool.sol";
import {FixtureContract} from "./fixtures/FixtureContract.t.sol";

contract BlendedPoolTest is Test, FixtureContract {
    function setUp() public {
        fixture();
    }

    /// @notice Test attempt to deposit; checking if variables are updated correctly
    function testFuzz_deposit_success(address user1, address user2, uint256 amount1, uint256 amount2) external {
        //setup
        uint256 user1Deposit = bound(
            amount1,
            blendedPool.getPoolInfo().minInvestmentAmount,
            blendedPool.getPoolInfo().investmentPoolSize / 3);

        uint256 user2Deposit = bound(
            amount2,
            blendedPool.getPoolInfo().minInvestmentAmount,
            blendedPool.getPoolInfo().investmentPoolSize / 3);

        createInvestorAndMintAsset(user1, user1Deposit);
        createInvestorAndMintAsset(user2, user2Deposit);
        vm.assume(user1 != user2);

        //testing initial condition
        assertEq(blendedPool.balanceOf(user1), 0);
        assertEq(blendedPool.balanceOf(user2), 0);
        assertEq(blendedPool.totalBalance(), 0);
        assertEq(blendedPool.totalDeposited(), 0);
        vm.expectRevert();
        blendedPool.getPendingWithdrawalAmount(user1);

        // user1
        vm.startPrank(user1);

        // deposit
        asset.approve(address(blendedPool), user1Deposit);
        blendedPool.deposit(user1Deposit);

        assertEq(blendedPool.balanceOf(user1), user1Deposit, "wrong LP balance for user1");
        assertEq(blendedPool.totalBalance(), user1Deposit, "wrong LA balance after user1 deposit");
        assertEq(blendedPool.totalDeposited(), user1Deposit, "wrong totalDeposit after user1 deposit");
        vm.stopPrank();

        // user2
        vm.startPrank(user2);

        // deposit
        asset.approve(address(blendedPool), user2Deposit);
        blendedPool.deposit(user2Deposit);

        assertEq(blendedPool.balanceOf(user2), user2Deposit, "wrong user2 LP balance");
        assertEq(blendedPool.totalBalance(), user1Deposit + user2Deposit, "wrong totalLA after user2");
        assertEq(blendedPool.totalDeposited(), user1Deposit + user2Deposit, "wrong totalDeposited after user2");
        vm.stopPrank();
    }

    /// @notice Test attempt to deposit below minimum
    function test_deposit_failure(address user) external {
        vm.startPrank(user);

        uint256 depositAmountBelowMin = 1;
        vm.expectRevert("P:DEP_AMT_BELOW_MIN");
        blendedPool.deposit(depositAmountBelowMin);

        vm.expectRevert("P:INVALID_VALUE");
        blendedPool.deposit(0);
        vm.stopPrank();
    }

    /// @notice Test attempt to withdraw; happy paths
    function testFuzz_withdraw_success(address user, uint256 amount) external {
        uint256 depositAmount = bound(amount, blendedPool.getPoolInfo().minInvestmentAmount, type(uint80).max);
        createInvestorAndMintAsset(user, depositAmount);

        vm.startPrank(user);

        // deposit
        asset.approve(address(blendedPool), depositAmount);
        blendedPool.deposit(depositAmount);

        // withdraw
        vm.warp(blendedPool.getPoolInfo().lockupPeriod + 1);
        blendedPool.withdraw(depositAmount);

        vm.stopPrank();
    }

    /// @notice Test attempt to withdraw; unhappy paths
    function testFuzz_withdraw_failure(address user, uint256 amount) external {
        uint256 depositAmount = bound(amount, blendedPool.getPoolInfo().minInvestmentAmount, type(uint80).max);
        createInvestorAndMintAsset(user, depositAmount);

        vm.startPrank(user);

        // deposit
        asset.approve(address(blendedPool), depositAmount);
        blendedPool.deposit(depositAmount);

        //attempt to withdraw too early fails
        vm.expectRevert("BP:TOKENS_LOCKED");
        blendedPool.withdraw(depositAmount);

        vm.warp(blendedPool.getPoolInfo().lockupPeriod + 1);

        //attempt to withdraw more than deposited
        vm.expectRevert("BP:INSUFFICIENT_FUNDS");
        blendedPool.withdraw(depositAmount + 1);

        vm.stopPrank();

        // drawdown pool
        vm.prank(OWNER_ADDRESS);
        blendedPool.borrow(OWNER_ADDRESS, depositAmount);

        vm.startPrank(user);
        //attempt to withdraw when not enough assets in pool
        vm.expectRevert("BP:NOT_ENOUGH_ASSETS");
        blendedPool.withdraw(depositAmount);
        vm.stopPrank();
    }

    /// @notice Test attempt to withdraw; both happy and unhappy paths
    function test_request_assets(address user) external {
        createInvestorAndMintAsset(user, 1000);

        vm.prank(OWNER_ADDRESS);
        regPool1.close();

        vm.expectRevert(bytes("P:NOT_POOL"));
        blendedPool.requestAssets(10);

        vm.startPrank(address(regPool1));

        vm.expectRevert(bytes("P:INVALID_VALUE"));
        blendedPool.requestAssets(0);

        vm.expectRevert(bytes("BP:NOT_ENOUGH_ASSETS"));
        blendedPool.requestAssets(100);

        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS);
        mintAsset(OWNER_ADDRESS, 100);
        asset.approve(address(blendedPool), 100);
        blendedPool.deposit(100);
        vm.stopPrank();

        vm.startPrank(address(regPool1));
        blendedPool.requestAssets(100);
        vm.stopPrank();
    }

    /// @notice Test attempt to borrow
    function testFuzz_borrow(address user1, address user2, uint256 amount1, uint256 amount2) external {
        //setup
        uint256 user1Deposit = bound(
            amount1,
            blendedPool.getPoolInfo().minInvestmentAmount,
            blendedPool.getPoolInfo().investmentPoolSize / 3);

        uint256 user2Deposit = bound(
            amount2,
            blendedPool.getPoolInfo().minInvestmentAmount,
            blendedPool.getPoolInfo().investmentPoolSize / 3);

        createInvestorAndMintAsset(user1, user1Deposit);
        createInvestorAndMintAsset(user2, user2Deposit);
        vm.assume(user1 != user2);

        //testing initial condition

        // user1 deposit
        vm.startPrank(user1);
        asset.approve(address(blendedPool), user1Deposit);
        blendedPool.deposit(user1Deposit);
        vm.stopPrank();

        // user2 deposit
        vm.startPrank(user2);
        asset.approve(address(blendedPool), user2Deposit);
        blendedPool.deposit(user2Deposit);
        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS);
        blendedPool.borrow(OWNER_ADDRESS, user1Deposit);
        blendedPool.borrow(OWNER_ADDRESS, user2Deposit);

        vm.expectRevert("P:BORROWED_MORE_THAN_DEPOSITED");
        blendedPool.borrow(OWNER_ADDRESS, 1);
        vm.stopPrank();
    }

    /// @notice Test attempt to repay
    function testFuzz_repay(address user1, address user2, uint256 amount1, uint256 amount2) external {
        //setup
        uint256 user1Deposit = bound(
            amount1,
            blendedPool.getPoolInfo().minInvestmentAmount,
            blendedPool.getPoolInfo().investmentPoolSize / 3);

        uint256 user2Deposit = bound(
            amount2,
            blendedPool.getPoolInfo().minInvestmentAmount,
            blendedPool.getPoolInfo().investmentPoolSize / 3);

        createInvestorAndMintAsset(user1, user1Deposit);
        createInvestorAndMintAsset(user2, user2Deposit);
        vm.assume(user1 != user2);

        //testing initial condition

        // user1 deposit
        vm.startPrank(user1);
        asset.approve(address(blendedPool), user1Deposit);
        blendedPool.deposit(user1Deposit);
        vm.stopPrank();

        // user2 deposit
        vm.startPrank(user2);
        asset.approve(address(blendedPool), user2Deposit);
        blendedPool.deposit(user2Deposit);
        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS);
        blendedPool.borrow(OWNER_ADDRESS, user1Deposit + user2Deposit);

        mintAsset(OWNER_ADDRESS, user1Deposit);
        asset.approve(address(blendedPool), user1Deposit);
        blendedPool.repay(user1Deposit);

        burnAllAssets(OWNER_ADDRESS);
        vm.expectRevert("P:NOT_ENOUGH_BALANCE");
        blendedPool.repay(user2Deposit);

        mintAsset(OWNER_ADDRESS, user2Deposit);
        asset.approve(address(blendedPool), user2Deposit);
        blendedPool.repay(user2Deposit);

        vm.expectRevert("P:CANT_REPAY_MORE_THAN_BORROWED");
        blendedPool.repay(1);
        vm.stopPrank();
    }

    /// @notice Test complete scenario of depositing, distribution of yield and withdraw
    function test_yields_repay_and_withdraw_success(address user1, address user2) external {
        uint256 user1Deposit = 100;
        uint256 user2Deposit = 1000;
        createInvestorAndMintAsset(user1, user1Deposit);
        createInvestorAndMintAsset(user2, user2Deposit);
        vm.assume(user1 != user2);

        assertEq(blendedPool.yieldBalanceAmount(), 0, "wrong yield balance");

        // User1 Deposit
        vm.startPrank(user1);
        asset.approve(address(blendedPool), user1Deposit);
        blendedPool.deposit(user1Deposit);
        vm.stopPrank();

        // User2 Deposit
        vm.startPrank(user2);
        asset.approve(address(blendedPool), user2Deposit);
        blendedPool.deposit(user2Deposit);
        vm.stopPrank();

        // Repay yield
        vm.startPrank(OWNER_ADDRESS);
        mintAsset(OWNER_ADDRESS, 1000);
        asset.approve(address(blendedPool), 1000);
        blendedPool.repayYield(1000);
        vm.stopPrank();

        assertEq(blendedPool.yieldBalanceAmount(), 1000, "wrong yield balance");

        //now we need to test if the users got assigned the correct yields
        uint256 user1Yields = blendedPool.yields(user1);
        uint256 user2Yields = blendedPool.yields(user2);
        assertEq(user1Yields, 90, "wrong yield user1");
        assertEq(user2Yields, 909, "wrong yield user2"); //NOTE: 1 is lost as a dust value :(

        // Withdraw yield for user1
        uint256 user1BalanceBefore = asset.balanceOf(user1);
        vm.prank(user1);
        blendedPool.withdrawYield();
        assertEq(asset.balanceOf(user1) - user1BalanceBefore, 90);

        // Withdraw yield for user2
        uint256 user2BalanceBefore = asset.balanceOf(user2);
        vm.prank(user2);
        blendedPool.withdrawYield();
        assertEq(asset.balanceOf(user2) - user2BalanceBefore, 909);

        assertApproxEqAbs(blendedPool.yieldBalanceAmount(), 0, 1, "wrong yield balance");
    }

    /// @notice Test overall balances correctness
    function test_balances(address user1, address user2, uint256 amount1, uint256 amount2) external {
        //setup
        uint256 user1Deposit = bound(
            amount1,
            blendedPool.getPoolInfo().minInvestmentAmount,
            blendedPool.getPoolInfo().investmentPoolSize / 3);

        uint256 user2Deposit = bound(
            amount2,
            blendedPool.getPoolInfo().minInvestmentAmount,
            blendedPool.getPoolInfo().investmentPoolSize / 3);

        createInvestorAndMintAsset(user1, user1Deposit);
        createInvestorAndMintAsset(user2, user2Deposit);
        vm.assume(user1 != user2);

        assertEq(blendedPool.yieldBalanceAmount(), 0);
        assertEq(blendedPool.principalBalanceAmount(), 0);
        assertEq(blendedPool.principalOut(), 0);

        // user1 deposit
        vm.startPrank(user1);
        asset.approve(address(blendedPool), user1Deposit);
        blendedPool.deposit(user1Deposit);
        vm.stopPrank();

        // user2 deposit
        vm.startPrank(user2);
        asset.approve(address(blendedPool), user2Deposit);
        blendedPool.deposit(user2Deposit);
        vm.stopPrank();

        assertEq(blendedPool.yieldBalanceAmount(), 0);
        assertEq(blendedPool.principalBalanceAmount(), user1Deposit + user2Deposit);
        assertEq(blendedPool.principalOut(), 0);

        // Repay yield
        vm.startPrank(OWNER_ADDRESS);
        mintAsset(OWNER_ADDRESS, 1000);
        asset.approve(address(blendedPool), 1000);
        blendedPool.repayYield(1000);
        vm.stopPrank();

        assertEq(blendedPool.yieldBalanceAmount(), 1000);
        assertEq(blendedPool.principalBalanceAmount(), user1Deposit + user2Deposit);
        assertEq(blendedPool.principalOut(), 0);

        // borrow 1
        uint256 borrow1Amount = user2Deposit;
        vm.startPrank(OWNER_ADDRESS);
        blendedPool.borrow(OWNER_ADDRESS, borrow1Amount);
        vm.stopPrank();

        assertEq(blendedPool.yieldBalanceAmount(), 1000);
        assertEq(blendedPool.principalBalanceAmount(), user1Deposit + user2Deposit - borrow1Amount);
        assertEq(blendedPool.principalOut(), borrow1Amount);

        // borrow 2
        uint256 borrow2Amount = user1Deposit;
        vm.startPrank(OWNER_ADDRESS);
        blendedPool.borrow(OWNER_ADDRESS, borrow2Amount);
        vm.stopPrank();

        assertEq(blendedPool.yieldBalanceAmount(), 1000);
        assertEq(blendedPool.principalBalanceAmount(), (user1Deposit + user2Deposit) - (borrow1Amount + borrow2Amount));
        assertEq(blendedPool.principalOut(), borrow1Amount + borrow2Amount);

        assertApproxEqAbs(blendedPool.yieldBalanceAmount(), blendedPool.yields(user1) + blendedPool.yields(user2), 1);

        // withdraw yield 1
        if (blendedPool.yields(user1) > 0)
        {
            vm.prank(user1);
            blendedPool.withdrawYield();
        }

        // withdraw yield 2
        if (blendedPool.yields(user2) > 0)
        {
            vm.prank(user2);
            blendedPool.withdrawYield();
        }

        assertApproxEqAbs(blendedPool.yieldBalanceAmount(), 0, 1);
        assertEq(blendedPool.principalBalanceAmount(), (user1Deposit + user2Deposit) - (borrow1Amount + borrow2Amount));
        assertEq(blendedPool.principalOut(), borrow1Amount + borrow2Amount);

        // repay
        vm.startPrank(OWNER_ADDRESS);
        mintAsset(OWNER_ADDRESS, borrow1Amount + borrow2Amount);
        asset.approve(address(blendedPool), borrow1Amount + borrow2Amount);
        blendedPool.repay(borrow1Amount + borrow2Amount);
        vm.stopPrank();

        assertApproxEqAbs(blendedPool.yieldBalanceAmount(), 0, 1);
        assertEq(blendedPool.principalBalanceAmount(), (user1Deposit + user2Deposit));
        assertEq(blendedPool.principalOut(), 0);
    }

    /// @notice Test failure scenario of distribution of yield
    function test_repay_yield_failure(address user) external {
        createInvestor(user);

        //a non-pool-admin address shouldn't be able to call repayYield()
        vm.prank(user);
        vm.expectRevert("PF:NOT_ADMIN");
        blendedPool.repayYield(1000);

        // Cannot repay zero yield
        vm.prank(OWNER_ADDRESS);
        vm.expectRevert("P:INVALID_VALUE");
        blendedPool.repayYield(0);

        uint256 adminBalance = asset.balanceOf(OWNER_ADDRESS);

        vm.prank(OWNER_ADDRESS);
        vm.expectRevert("P:NOT_ENOUGH_BALANCE");
        blendedPool.repayYield(adminBalance + 1);
    }

    /// @notice Test complete scenario of subsiding regular pool with blended pool
    function test_subsiding_reg_pool_with_blended_pool(address user) external {
        createInvestorAndMintAsset(user, 1000);

        // Create pool
        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);
        address poolAddress = poolFactory.createPool("1", address(asset), 1000, 100, 1000);
        Pool pool = Pool(poolAddress);
        vm.stopPrank();

        //Deposit to pool
        vm.startPrank(user);
        asset.approve(poolAddress, 500);
        pool.deposit(500);
        vm.stopPrank();

        // Close pool and borrow
        vm.startPrank(OWNER_ADDRESS);
        pool.close();
        pool.borrow(OWNER_ADDRESS, 500);

        // Deposit to Blended Pool
        mintAsset(OWNER_ADDRESS, 500);
        asset.approve(address(blendedPool), 500);
        blendedPool.deposit(500);
        vm.stopPrank();

        // locked period is passed
        vm.warp(block.timestamp + 1001);

        //now let's withdraw. The blended pool will help
        vm.startPrank(user);
        pool.withdraw(500);
    }
}
