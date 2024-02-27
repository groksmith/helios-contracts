pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {MockTokenERC20} from "./mocks/MockTokenERC20.sol";
import {AbstractPool} from "../contracts/pool/AbstractPool.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import {PoolLibrary} from "../contracts/library/PoolLibrary.sol";

import {FixtureContract} from "./fixtures/FixtureContract.t.sol";

contract RegPoolTest is FixtureContract {
    event PendingYield(address indexed recipient, uint256 amount);
    event PendingWithdrawal(address indexed investor, uint256 amount);

    function setUp() public {
        fixture();
    }

    /// @notice Test attempt to deposit; checking if variables are updated correctly
    function testFuzz_deposit_success(address user1, address user2, uint256 amount1, uint256 amount2) external {
        uint256 user1Deposit = bound(
            amount1,
            regPool1.getPoolInfo().minInvestmentAmount,
            regPool1.getPoolInfo().investmentPoolSize / 3);

        uint256 user2Deposit = bound(
            amount2,
            regPool1.getPoolInfo().minInvestmentAmount,
            regPool1.getPoolInfo().investmentPoolSize / 3);

        user1 = createInvestorAndMintAsset(user1, user1Deposit);
        user2 = createInvestorAndMintAsset(user2, user2Deposit);

        vm.assume(user1 != user2);

        vm.startPrank(user1);

        //testing initial condition i.e. zeroes
        assertEq(regPool1.balanceOf(user1), 0);
        assertEq(regPool1.totalDeposited(), 0);
        assertEq(regPool1.getHoldersCount(), 0, "wrong holder number");

        asset.approve(address(regPool1), user1Deposit);
        regPool1.deposit(user1Deposit);

        //user's LP balance should be 100 now
        assertEq(regPool1.balanceOf(user1), user1Deposit, "wrong LP balance for user1");

        //pool's total minted should also be user1Deposit
        assertEq(regPool1.totalDeposited(), user1Deposit, "wrong totalDeposit after user1 deposit");
        vm.stopPrank();

        //now let's test for user2
        vm.startPrank(user2);
        assertEq(regPool1.balanceOf(user2), 0, "user2 shouldn't have > 0 atm");

        asset.approve(address(regPool1), user2Deposit);
        regPool1.deposit(user2Deposit);

        assertEq(regPool1.balanceOf(user2), user2Deposit, "wrong user2 LP balance");

        //pool's total minted should also be user1Deposit
        assertEq(regPool1.totalDeposited(), user1Deposit + user2Deposit, "wrong totalDeposited after user2");
        assertEq(regPool1.getHoldersCount(), 2, "wrong holder number");

        vm.stopPrank();
    }

    /// @notice Test attempt to deposit below minimum
    function testFuzz_deposit_failure(address user1, address user2) external {
        uint256 depositAmountMax = regPool1.getPoolInfo().investmentPoolSize;
        uint256 depositAmountBelowMin = regPool1.getPoolInfo().minInvestmentAmount - 1;

        vm.startPrank(user1);
        createInvestorAndMintAsset(user1, depositAmountMax + 1);
        asset.approve(address(regPool1), depositAmountMax + 1);

        vm.expectRevert("P:DEP_AMT_BELOW_MIN");
        regPool1.deposit(depositAmountBelowMin);

        vm.expectRevert("P:MAX_POOL_SIZE_REACHED");
        regPool1.deposit(depositAmountMax + 1);

        regPool1.deposit(depositAmountMax);
        vm.stopPrank();

        vm.startPrank(user2);
        createInvestorAndMintAsset(user2, depositAmountMax + 1);
        asset.approve(address(regPool1), depositAmountMax + 1);
        vm.expectRevert("P:MAX_POOL_SIZE_REACHED");
        regPool1.deposit(1);
        vm.stopPrank();
    }

    /// @notice Test attempt to withdraw, happy paths
    function testFuzz_withdraw(address user, uint256 amount) external {
        uint256 amountBounded = bound(
            amount, regPool1.getPoolInfo().minInvestmentAmount,
            regPool1.getPoolInfo().investmentPoolSize);

        user = createInvestorAndMintAsset(user, amountBounded);

        vm.startPrank(user);
        uint256 currentTime = block.timestamp;

        asset.approve(address(regPool1), amountBounded);

        regPool1.deposit(amountBounded);

        vm.warp(currentTime + 1000);

        // the user can withdraw the sum he has deposited earlier
        regPool1.withdraw(amountBounded - 1);
        regPool1.withdraw(1);

        vm.stopPrank();
    }

    /// @notice Test attempt to withdraw with BP compensation
    function testFuzz_withdraw_with_request_from_blended_pool(address regularPoolInvestor, address blendedPoolInvestor, uint256 amount) external {
        vm.assume(regularPoolInvestor != blendedPoolInvestor);

        uint256 regularPoolInvestment = bound(
            amount,
            regPool1.getPoolInfo().minInvestmentAmount,
            regPool1.getPoolInfo().investmentPoolSize);

        uint256 blendedPoolInvestment = regularPoolInvestment + 1000;

        regularPoolInvestor = createInvestorAndMintAsset(regularPoolInvestor, regularPoolInvestment);
        blendedPoolInvestor = createInvestorAndMintAsset(blendedPoolInvestor, blendedPoolInvestment);

        assertEq(regPool1.balanceOf(address(blendedPool)), 0, "Expect no tokens from BP");

        vm.startPrank(blendedPoolInvestor);
        assertEq(blendedPool.totalBalance(), 0, "BP is not empty");
        asset.approve(address(blendedPool), blendedPoolInvestment);
        blendedPool.deposit(blendedPoolInvestment);
        assertEq(blendedPool.totalSupply(), blendedPoolInvestment, "Expecting increasing BP by blendedPoolInvestment");
        assertEq(blendedPool.totalBalance(), blendedPoolInvestment, "Wrong BP totalBalance");
        vm.stopPrank();

        vm.startPrank(regularPoolInvestor);
        uint256 currentTime = block.timestamp;
        assertEq(regPool1.totalBalance(), 0, "RP is not empty");
        asset.approve(address(regPool1), regularPoolInvestment);
        regPool1.deposit(regularPoolInvestment);
        assertEq(regPool1.totalBalance(), regularPoolInvestment, "Wrong RP totalBalance");
        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS);
        uint256 borrowAmount = regPool1.totalBalance() - regPool1.principalOut();
        regPool1.borrow(OWNER_ADDRESS, borrowAmount);
        assertEq(regPool1.totalBalance(), 0, "Regular pool is not empty");
        vm.stopPrank();

        vm.warp(currentTime + 1000);

        vm.startPrank(regularPoolInvestor);
        assertEq(regPool1.totalBalance(), 0, "Regular pool is not empty");
        // the user can withdraw the sum he has deposited earlier
        regPool1.withdraw(regularPoolInvestment);
        assertEq(regPool1.totalBalance(), 0, "Wrong RP balance");
        assertEq(regPool1.balanceOf(address(blendedPool)), regularPoolInvestment, "Wrong token amount from RP");

        vm.stopPrank();
    }

    /// @notice Test attempt to withdraw with admin approval
    function testFuzz_withdraw_with_pending(address regularPoolInvestor, uint256 amount) external {
        uint256 regularPoolInvestment = bound(
            amount,
            regPool1.getPoolInfo().minInvestmentAmount,
            regPool1.getPoolInfo().investmentPoolSize);

        uint256 currentTime = block.timestamp;

        regularPoolInvestor = createInvestorAndMintAsset(regularPoolInvestor, regularPoolInvestment);

        assertEq(regPool1.balanceOf(address(blendedPool)), 0, "Expect no tokens from BP");
        assertEq(blendedPool.totalBalance(), 0, "BP is not empty");

        vm.startPrank(regularPoolInvestor);
        assertEq(regPool1.totalBalance(), 0, "RP is not empty");
        asset.approve(address(regPool1), regularPoolInvestment);
        regPool1.deposit(regularPoolInvestment);
        assertEq(regPool1.totalBalance(), regularPoolInvestment, "Wrong RP totalBalance");
        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS);
        uint256 borrowAmount = regPool1.totalBalance() - regPool1.principalOut();
        regPool1.borrow(OWNER_ADDRESS, borrowAmount);
        assertEq(regPool1.totalBalance(), 0, "Regular pool is not empty");
        vm.stopPrank();

        vm.warp(currentTime + 1000);

        vm.startPrank(regularPoolInvestor);
        assertEq(regPool1.totalBalance(), 0, "Regular pool is not empty");

        vm.expectEmit(true, true, false, false);
        // The expected event signature
        emit PendingWithdrawal(regularPoolInvestor, regularPoolInvestment);
        regPool1.withdraw(regularPoolInvestment);

        uint256 pendingAmount = regPool1.pendingWithdrawals(address(regularPoolInvestor));
        assertEq(pendingAmount, regularPoolInvestment, "Wrong pendingWithdrawals amount");

        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS);
        mintAsset(OWNER_ADDRESS, regularPoolInvestment);
        asset.approve(address(regPool1), regularPoolInvestment);
        regPool1.concludePendingWithdrawal(regularPoolInvestor);
        vm.stopPrank();
    }

    /// @notice Test attempt to withdraw, unhappy paths
    function testFuzz_withdraw_failed(address user, uint256 amount) external {
        uint256 amountBounded = bound(
            amount,
            regPool1.getPoolInfo().minInvestmentAmount,
            regPool1.getPoolInfo().investmentPoolSize);

        user = createInvestorAndMintAsset(user, amountBounded);

        vm.startPrank(user);
        uint256 currentTime = block.timestamp;

        asset.approve(address(regPool1), amountBounded);

        regPool1.deposit(amountBounded);

        vm.expectRevert("P:TOKENS_LOCKED");
        regPool1.withdraw(amountBounded);

        vm.warp(currentTime + 1000);

        regPool1.withdraw(amountBounded);

        vm.expectRevert("P:INSUFFICIENT_FUNDS");
        regPool1.withdraw(amountBounded);

        vm.stopPrank();
    }

    /// @notice Test locked/unlocked deposits amounts
    function testFuzz_unlocked_to_withdraw(address user, uint256 amount) external {
        uint256 depositAmount = bound(
            amount,
            regPool1.getPoolInfo().minInvestmentAmount,
            regPool1.getPoolInfo().investmentPoolSize / 3);

        user = createInvestorAndMintAsset(user, 2 * depositAmount);

        vm.startPrank(user);

        asset.approve(address(regPool1), depositAmount);
        regPool1.deposit(depositAmount);

        uint256 unlockedFundsAmount = regPool1.unlockedToWithdraw(user);
        assertEq(unlockedFundsAmount, 0);

        vm.warp(block.timestamp + regPool1.getPoolInfo().lockupPeriod + 1);

        asset.approve(address(regPool1), depositAmount);
        regPool1.deposit(depositAmount);

        unlockedFundsAmount = regPool1.unlockedToWithdraw(user);
        assertEq(unlockedFundsAmount, depositAmount);

        vm.warp(block.timestamp + regPool1.getPoolInfo().lockupPeriod + 1);
        unlockedFundsAmount = regPool1.unlockedToWithdraw(user);
        assertEq(unlockedFundsAmount, 2 * depositAmount);
    }

    /// @notice Test repay
    function testFuzz_repay(address investor, uint256 depositAmount, uint256 yieldAmount) external {
        vm.startPrank(investor);

        depositAmount = bound(
            depositAmount,
            regPool1.getPoolInfo().minInvestmentAmount,
            regPool1.getPoolInfo().investmentPoolSize);

        yieldAmount = bound(yieldAmount, 0, asset.totalSupply());

        createInvestorAndMintAsset(investor, depositAmount);

        asset.approve(address(regPool1), depositAmount);
        //the user can withdraw the sum he has deposited earlier
        regPool1.deposit(depositAmount);
        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);
        asset.approve(address(regPool1), depositAmount + yieldAmount);
        mintAsset(OWNER_ADDRESS, yieldAmount);

        // Just toying with multiple borrow and repay
        regPool1.borrow(OWNER_ADDRESS, depositAmount - 10);
        assertEq(regPool1.principalOut(), depositAmount - 10);

        regPool1.borrow(OWNER_ADDRESS, 10);
        assertEq(regPool1.principalOut(), depositAmount);

        regPool1.repay(depositAmount - 10);
        assertEq(regPool1.principalOut(), 10);
        regPool1.repay(10);
        assertEq(regPool1.principalOut(), 0);

        regPool1.repay(yieldAmount);
        assertEq(regPool1.principalOut(), 0);

        uint256 balance = asset.balanceOf(OWNER_ADDRESS);
        asset.approve(address(regPool1), 2 * balance);

        vm.expectRevert(bytes("P:NOT_ENOUGH_BALANCE"));
        regPool1.repay(balance + 10);
        // Stop toying

        vm.stopPrank();
    }

    /// @notice Test deposit above maxPoolSize
    function testFuzz_max_pool_size(uint256 _maxPoolSize) external {
        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);

        _maxPoolSize = bound(_maxPoolSize, 1, type(uint256).max - 1);
        address poolAddress = poolFactory.createPool(
            "1",
            address(asset),
            1000,
            0,
            _maxPoolSize
        );

        Pool pool = Pool(poolAddress);

        asset.approve(poolAddress, 1000);
        vm.expectRevert("P:MAX_POOL_SIZE_REACHED");
        pool.deposit(_maxPoolSize + 1);
        vm.stopPrank();
    }

    /// @notice Test complete scenario of depositing, distribution of yield and withdraw
    function testFuzz_distribute_yields_and_withdraw(address user1, address user2) external {
        vm.assume(user1 != user2);

        user1 = createInvestorAndMintAsset(user1, 1000);
        user2 = createInvestorAndMintAsset(user2, 1000);

        //firstly the users need to deposit before withdrawing
        uint256 user1Deposit = 100;
        vm.startPrank(user1);
        asset.approve(address(regPool1), user1Deposit);
        regPool1.deposit(user1Deposit);
        vm.stopPrank();

        uint256 user2Deposit = 900;
        vm.startPrank(user2);
        asset.approve(address(regPool1), user2Deposit);
        regPool1.deposit(user2Deposit);
        vm.stopPrank();

        uint256 yieldGenerated = 1000;

        //a non-pool-admin address shouldn't be able to call distributeYields()
        vm.prank(user1);

        // No yield yet
        vm.expectRevert("P:ZERO_YIELD");
        regPool1.withdrawYield();

        vm.expectRevert("PF:NOT_ADMIN");
        regPool1.distributeYields(yieldGenerated);

        //only the pool admin can call distributeYields()
        vm.startPrank(OWNER_ADDRESS);
        vm.expectRevert("P:INVALID_VALUE");
        regPool1.distributeYields(0);

        mintAsset(OWNER_ADDRESS, yieldGenerated);
        asset.approve(address(regPool1), yieldGenerated);
        regPool1.repay(yieldGenerated);
        regPool1.distributeYields(yieldGenerated);

        //now we need to test if the users got assigned the correct yields
        uint256 user1Yields = regPool1.yields(user1);
        uint256 user2Yields = regPool1.yields(user2);

        assertEq(user1Yields, 100, "wrong yield user1");
        assertEq(user2Yields, 900, "wrong yield user2"); //NOTE: 1 is lost as a dust value :(

        vm.stopPrank();

        vm.startPrank(user1);
        uint256 user1BalanceBefore = asset.balanceOf(user1);
        regPool1.withdrawYield();

        assertEq(
            asset.balanceOf(user1) - user1BalanceBefore,
            100,
            "user1 balance not upd after withdrawYield()"
        );
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 user2BalanceBefore = asset.balanceOf(user2);
        regPool1.withdrawYield();
        assertEq(
            asset.balanceOf(user2) - user2BalanceBefore,
            900,
            "user2 balance not upd after withdrawYield()"
        );
        vm.stopPrank();
    }

    /// @notice Test getHolders
    function testFuzz_get_holder_by_index(address user1, address user2) external {
        vm.assume(user1 != user2);

        user1 = createInvestorAndMintAsset(user1, 1000);
        user2 = createInvestorAndMintAsset(user2, 1000);

        //firstly the users need to deposit before withdrawing
        uint256 user1Deposit = 100;
        vm.startPrank(user1);
        asset.approve(address(regPool1), user1Deposit);
        regPool1.deposit(user1Deposit);
        vm.stopPrank();

        assertEq(regPool1.getHolderByIndex(0), user1);

        uint256 user2Deposit = 900;
        vm.startPrank(user2);
        asset.approve(address(regPool1), user2Deposit);
        regPool1.deposit(user2Deposit);
        vm.stopPrank();

        assertEq(regPool1.getHolderByIndex(1), user2);

        vm.expectRevert("PL:INVALID_INDEX");
        regPool1.getHolderByIndex(3);
    }

    /// @notice Test attempt to change states
    function testFuzz_pool_close(address user1) external {
        uint256 depositAmount = 100000;

        vm.startPrank(user1);
        createInvestorAndMintAsset(user1, depositAmount);
        asset.approve(address(regPool1), depositAmount);
        regPool1.deposit(depositAmount);
        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);

        // Closed. Deny any additional deposits
        regPool1.close();
        vm.stopPrank();

        vm.startPrank(user1);
        createInvestorAndMintAsset(user1, depositAmount);
        asset.approve(address(regPool1), depositAmount);
        vm.expectRevert("P:BAD_STATE");
        regPool1.deposit(depositAmount);
        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);

        // Cannot close again
        vm.expectRevert("P:BAD_STATE");
        regPool1.close();
    }
    /// @notice Test attempt transfer tokens
    function testFuzz_pool_deposit_transfer(address holder, address newHolder, uint256 amount1, uint256 amount2) external {
        vm.assume(holder != address(0));
        vm.assume(newHolder != address(0));
        vm.assume(newHolder != holder);

        uint256 amountBounded1 = bound(
            amount1,
            regPool1.getPoolInfo().minInvestmentAmount,
            regPool1.getPoolInfo().investmentPoolSize / 4);

        uint256 amountBounded2 = bound(
            amount2,
            regPool1.getPoolInfo().minInvestmentAmount,
            regPool1.getPoolInfo().investmentPoolSize / 4);

        uint256 lockTime1 = block.timestamp + 1000;
        uint256 lockTime2 = lockTime1 + 6000;

        vm.startPrank(holder);
        mintAsset(holder, amountBounded1);
        asset.approve(address(regPool1), amountBounded1);
        regPool1.deposit(amountBounded1);

        vm.expectRevert("P:TOKENS_LOCKED");
        regPool1.transfer(newHolder, amountBounded1);

        vm.warp(lockTime1);
        mintAsset(holder, amountBounded2);
        asset.approve(address(regPool1), amountBounded2);
        regPool1.deposit(amountBounded2);

        vm.warp(lockTime2);
        mintAsset(holder, amountBounded1);
        asset.approve(address(regPool1), amountBounded1);
        regPool1.deposit(amountBounded1);

        uint256 holderTokensAmountBefore = regPool1.balanceOf(holder);
        uint256 newHolderTokensAmountBefore = regPool1.balanceOf(newHolder);

        regPool1.transfer(newHolder, amountBounded1 + amountBounded2);

        uint256 holderTokensAmountAfter = regPool1.balanceOf(holder);
        uint256 newHolderTokensAmountAfter = regPool1.balanceOf(newHolder);

        assertEq(
            holderTokensAmountBefore - holderTokensAmountAfter,
            newHolderTokensAmountAfter - newHolderTokensAmountBefore);
    }
}
