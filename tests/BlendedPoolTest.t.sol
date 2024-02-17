// @author Tigran Arakelyan
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {MockTokenERC20} from "./mocks/MockTokenERC20.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {AbstractPool} from "../contracts/pool/AbstractPool.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import {BlendedPool} from "../contracts/pool/BlendedPool.sol";

import {FixtureContract} from "./fixtures/FixtureContract.t.sol";

contract BlendedPoolTest is Test, FixtureContract {
    event PendingYield(address indexed recipient, uint256 amount);
    event WithdrawalOverThreshold(address indexed caller, uint256 amount);

    function setUp() public {
        fixture();
        vm.prank(OWNER_ADDRESS);
        asset.approve(address(blendedPool), 1000);
        vm.stopPrank();
        vm.prank(USER_ADDRESS);
        asset.approve(address(blendedPool), 1000);
        vm.stopPrank();
    }

    /// @notice Test attempt to deposit; checking if variables are updated correctly
    function test_depositSuccess(address user1, address user2) external {
        createInvestorAndMintAsset(user1, 1000);
        createInvestorAndMintAsset(user2, 1000);
        vm.assume(user1 != user2);

        vm.startPrank(user1);

        //testing initial condition i.e. zeroes
        assertEq(blendedPool.balanceOf(user1), 0);
        assertEq(blendedPool.totalBalance(), 0);
        assertEq(blendedPool.totalDeposited(), 0);

        uint256 user1Deposit = 100;
        asset.approve(address(blendedPool), user1Deposit);
        blendedPool.deposit(user1Deposit);

        //user's LP balance should be 100 now
        assertEq(blendedPool.balanceOf(user1), user1Deposit, "wrong LP balance for user1");

        //pool's total LA balance should be user1Deposit now
        assertEq(blendedPool.totalBalance(), user1Deposit, "wrong LA balance after user1 deposit");

        //pool's total minted should also be user1Deposit
        assertEq(blendedPool.totalDeposited(), user1Deposit, "wrong totalDeposit after user1 deposit");
        vm.stopPrank();

        //now let's test for user2
        vm.startPrank(user2);
        assertEq(blendedPool.balanceOf(user2), 0, "user2 shouldn't have >0 atm");
        uint256 user2Deposit = 101;

        asset.approve(address(blendedPool), user2Deposit);
        blendedPool.deposit(user2Deposit);

        assertEq(blendedPool.balanceOf(user2), user2Deposit, "wrong user2 LP balance");

        //pool's total LA balance should be user1Deposit now
        assertEq(blendedPool.totalBalance(), user1Deposit + user2Deposit, "wrong totalLA after user2");

        //pool's total minted should also be user1Deposit
        assertEq(blendedPool.totalDeposited(), user1Deposit + user2Deposit, "wrong totalDeposited after user2");
        vm.stopPrank();
    }

    /// @notice Test attempt to deposit below minimum
    function test_depositFailure(address user) external {
        vm.startPrank(user);
        uint256 depositAmountBelowMin = 1;
        vm.expectRevert("P:DEP_AMT_BELOW_MIN");
        blendedPool.deposit(depositAmountBelowMin);
    }

    /// @notice Test attempt to withdraw; both happy and unhappy paths
    function test_withdraw(address user) external {
        createInvestorAndMintAsset(user, 1000);

        vm.startPrank(user);
        uint256 depositAmount = 150;
        uint256 currentTime = block.timestamp;

        asset.approve(address(blendedPool), depositAmount);
        //the user can withdraw the sum he has deposited earlier
        blendedPool.deposit(depositAmount);

        //attempt to withdraw too early fails
        vm.expectRevert("P:TOKENS_LOCKED");
        blendedPool.withdraw(depositAmount);

        vm.warp(currentTime + 1000);
        blendedPool.withdraw(depositAmount);

        vm.stopPrank();
    }

    /// @notice Test complete scenario of depositing, distribution of yield and withdraw
    function test_distributeYieldsAndWithdraw(address user1, address user2) external {
        createInvestorAndMintAsset(user1, 1000);
        createInvestorAndMintAsset(user2, 1000);
        vm.assume(user1 != user2);

        //firstly the users need to deposit before withdrawing
        uint256 user1Deposit = 100;
        vm.startPrank(user1);
        asset.approve(address(blendedPool), user1Deposit);
        blendedPool.deposit(user1Deposit);
        vm.stopPrank();

        uint256 user2Deposit = 1000;
        vm.startPrank(user2);
        asset.approve(address(blendedPool), user2Deposit);
        blendedPool.deposit(user2Deposit);
        vm.stopPrank();

        //only the pool admin can call distributeYields()
        vm.prank(OWNER_ADDRESS);
        blendedPool.distributeYields(1000);

        //now we need to test if the users got assigned the correct yields
        uint256 user1Yields = blendedPool.yields(user1);
        uint256 user2Yields = blendedPool.yields(user2);
        assertEq(user1Yields, 90, "wrong yield user1");
        assertEq(user2Yields, 909, "wrong yield user2"); //NOTE: 1 is lost as a dust value :(

        uint256 user1BalanceBefore = asset.balanceOf(user1);
        vm.prank(user1);
        blendedPool.withdrawYield();
        assertApproxEqAbs(
            asset.balanceOf(user1) - user1BalanceBefore,
            90,
            1
        );

        uint256 user2BalanceBefore = asset.balanceOf(user2);
        vm.prank(user2);
        blendedPool.withdrawYield();
        assertApproxEqAbs(
            asset.balanceOf(user2) - user2BalanceBefore,
            910,
            1
        );

        //a non-pool-admin address shouldn't be able to call distributeYields()
        vm.prank(user1);
        vm.expectRevert("PF:NOT_ADMIN");
        blendedPool.distributeYields(1000);
    }

    /// @notice Test scenario when there are not enough funds on the pool
    function test_insufficientFundsWithdrawYield(address user) external {
        createInvestorAndMintAsset(user, 1000);

        //firstly the users need to deposit before withdrawing
        uint256 user1Deposit = 100;
        vm.startPrank(user);
        asset.approve(address(blendedPool), 10000);
        blendedPool.deposit(user1Deposit);
        vm.stopPrank();

        //only the pool admin can call distributeYields()
        vm.prank(OWNER_ADDRESS);
        blendedPool.distributeYields(1000);

        vm.prank(OWNER_ADDRESS);
        vm.expectRevert("P:INVALID_VALUE");
        blendedPool.distributeYields(0);

        assertEq(blendedPool.yields(user), 1000, "yields should be 1000 atm");

        // now let's deplete the pool's balance
        vm.startPrank(OWNER_ADDRESS);
        uint256 borrowAmount = blendedPool.totalSupply() - blendedPool.principalOut();
        blendedPool.borrow(OWNER_ADDRESS, borrowAmount);
        vm.stopPrank();

        //..and withdraw yields as user1
        vm.startPrank(user);
        vm.expectEmit(false, false, false, false);
        // The expected event signature
        emit PendingYield(user, 1000);
        assertFalse(blendedPool.withdrawYield(), "should return false if not enough LA");

        vm.stopPrank();

        assertEq(blendedPool.yields(user), 0, "yields should be 0 after withdraw attempt");

        assertEq(blendedPool.pendingYields(user), 1000, "pending yields should be 1000 after withdraw attempt");

        uint256 user1BalanceBefore = asset.balanceOf(user);

        mintAsset(OWNER_ADDRESS, 1000);
        vm.startPrank(OWNER_ADDRESS);
        asset.approve(address(blendedPool), 1000);
        blendedPool.repay(1000);
        blendedPool.concludePendingYield(user);

        uint256 user1BalanceAfter = asset.balanceOf(user);

        //checking if the user got his money now
        assertEq(user1BalanceAfter, user1BalanceBefore + 1000, "invalid user1 LA balance after concluding");
    }

    function test_subsidingRegPoolWithBlendedPool(address user) external {
        createInvestorAndMintAsset(user, 1000);

        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);
        address poolAddress = poolFactory.createPool(
            "1", address(asset), 2000, 1000, 1000, 100, 500, 1000
        );

        Pool pool = Pool(poolAddress);

        vm.stopPrank();

        //a user deposits some LA to the RegPool
        vm.startPrank(user);
        asset.approve(poolAddress, 1000);
        pool.deposit(500);
        vm.stopPrank();

        //the admin distributes yields and takes all the LA, emptying the pool
        vm.startPrank(OWNER_ADDRESS);

        pool.distributeYields(100);
        pool.borrow(OWNER_ADDRESS, 100);
        vm.stopPrank();

        //now let's repay LA to the blended pool
        vm.startPrank(OWNER_ADDRESS);
        mintAsset(OWNER_ADDRESS, 100);
        asset.approve(address(blendedPool), 100);
        blendedPool.repay(100);
        vm.stopPrank();

        //now let's withdraw yield. The blended pool will help
        vm.startPrank(user);
        asset.approve(poolAddress, 10000);
        pool.withdrawYield();
    }
}
