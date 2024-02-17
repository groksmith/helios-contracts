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
    using PoolLibrary for PoolLibrary.PoolInfo;

    event PendingYield(address indexed recipient, uint256 amount);
    event WithdrawalOverThreshold(address indexed caller, uint256 amount);

    function setUp() public {
        fixture();
    }

    /// @notice Test attempt to deposit; checking if variables are updated correctly
    function testFuzz_depositSuccess(address user1, address user2) external {
        user1 = createInvestorAndMintAsset(user1, 1000);
        user2 = createInvestorAndMintAsset(user2, 1000);
        vm.assume(user1 != user2);

        vm.startPrank(user1);

        //testing initial condition i.e. zeroes
        assertEq(regPool1.balanceOf(user1), 0);
        assertEq(regPool1.totalDeposited(), 0);
        assertEq(regPool1.getHoldersCount(), 0, "wrong holder number");

        uint256 user1Deposit = 100;
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
        uint256 user2Deposit = 101;

        asset.approve(address(regPool1), user2Deposit);
        regPool1.deposit(user2Deposit);

        assertEq(regPool1.balanceOf(user2), user2Deposit, "wrong user2 LP balance");

        //pool's total minted should also be user1Deposit
        assertEq(regPool1.totalDeposited(), user1Deposit + user2Deposit, "wrong totalDeposited after user2");
        assertEq(regPool1.getHoldersCount(), 2, "wrong holder number");

        vm.stopPrank();
    }

    /// @notice Test attempt to deposit below minimum
    function testFuzz_depositFailure(address user1, address user2) external {
        uint256 depositAmountMax = 100000;

        vm.startPrank(user1);
        createInvestorAndMintAsset(user1, depositAmountMax + 1);
        asset.approve(address(regPool1), depositAmountMax + 1);

        uint256 depositAmountBelowMin = 99;
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

    /// @notice Test attempt to withdraw; both happy and unhappy paths
    function testFuzz_withdraw(address user, uint256 amount) external {
        uint256 amountBounded = bound(amount, regPool1.getPoolInfo().minInvestmentAmount, regPool1.getPoolInfo().investmentPoolSize);
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

    /// @notice Test attempt to withdraw; both happy and unhappy paths
    function testFuzz_withdraw_failed(address user, uint256 amount) external {
        uint256 amountBounded = bound(amount, regPool1.getPoolInfo().minInvestmentAmount, regPool1.getPoolInfo().investmentPoolSize);
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

    /// @notice Test attempt to withdraw; both happy and unhappy paths
    function testFuzz_unlockedToWithdraw(address user) external {
        user = createInvestorAndMintAsset(user, 1000);

        vm.startPrank(user);
        uint256 depositAmount = 150;

        asset.approve(address(regPool1), depositAmount);
        regPool1.deposit(depositAmount);

        uint256 unlockedFundsAmount = regPool1.unlockedToWithdraw(user);
        assertEq(unlockedFundsAmount, 0);

        vm.warp(block.timestamp + regPool1.getPoolInfo().lockupPeriod + 10);

        asset.approve(address(regPool1), depositAmount);
        regPool1.deposit(depositAmount);

        unlockedFundsAmount = regPool1.unlockedToWithdraw(user);
        assertEq(unlockedFundsAmount, depositAmount);

        vm.warp(block.timestamp + regPool1.getPoolInfo().lockupPeriod + 10);
        unlockedFundsAmount = regPool1.unlockedToWithdraw(user);
        assertEq(unlockedFundsAmount, 2 * depositAmount);
    }

    /// @notice Test repay
    function testFuzz_repay(address investor, uint256 depositAmount, uint256 yieldAmount) external {
        vm.startPrank(investor);
        PoolLibrary.PoolInfo memory poolInfo = regPool1.getPoolInfo();

        depositAmount = uint64(bound(depositAmount, poolInfo.minInvestmentAmount, poolInfo.investmentPoolSize));
        yieldAmount = uint64(bound(yieldAmount, 0, asset.totalSupply()));

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

    function testFuzz_maxPoolSize(uint256 _maxPoolSize) external {
        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);

        _maxPoolSize = bound(_maxPoolSize, 1, 1e36);
        address poolAddress = poolFactory.createPool(
            "1",
            address(asset),
            2000,
            1000,
            _maxPoolSize,
            0,
            500,
            1000
        );

        Pool pool = Pool(poolAddress);

        asset.approve(poolAddress, 1000);
        vm.expectRevert("P:MAX_POOL_SIZE_REACHED");
        pool.deposit(_maxPoolSize + 1);
        vm.stopPrank();
    }

    function test_maxPoolSize(address user, uint256 _maxPoolSize) external {
        createInvestorAndMintAsset(user, 1000);

        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);

        _maxPoolSize = bound(_maxPoolSize, 1, type(uint256).max - 1);
        address poolAddress = poolFactory.createPool(
            "1",
            address(asset),
            2000,
            1000,
            _maxPoolSize,
            0,
            500,
            1000
        );
        vm.stopPrank();

        Pool pool = Pool(poolAddress);

        vm.startPrank(user);
        asset.approve(poolAddress, 1000);
        vm.expectRevert("P:MAX_POOL_SIZE_REACHED");
        pool.deposit(_maxPoolSize + 1);
        vm.stopPrank();
    }

    /// @notice Test complete scenario of depositing, distribution of yield and withdraw
    function testFuzz_distributeYieldsAndWithdraw(address user1, address user2) external {
        user1 = createInvestorAndMintAsset(user1, 1000);
        user2 = createInvestorAndMintAsset(user2, 1000);
        vm.assume(user1 != user2);

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
        vm.stopPrank();

        //now we need to test if the users got assigned the correct yields
        uint256 user1Yields = regPool1.yields(user1);
        uint256 user2Yields = regPool1.yields(user2);

        assertEq(user1Yields, 100, "wrong yield user1");
        assertEq(user2Yields, 900, "wrong yield user2"); //NOTE: 1 is lost as a dust value :(

        uint256 user1BalanceBefore = asset.balanceOf(user1);
        vm.prank(user1);
        regPool1.withdrawYield();
        assertEq(
            asset.balanceOf(user1) - user1BalanceBefore,
            100,
            "user1 balance not upd after withdrawYield()"
        );

        uint256 user2BalanceBefore = asset.balanceOf(user2);
        vm.prank(user2);
        regPool1.withdrawYield();
        assertEq(
            asset.balanceOf(user2) - user2BalanceBefore,
            900,
            "user2 balance not upd after withdrawYield()"
        );
    }

    function testFuzz_getHolderByIndex(address user1, address user2) external {
        user1 = createInvestorAndMintAsset(user1, 1000);
        user2 = createInvestorAndMintAsset(user2, 1000);
        vm.assume(user1 != user2);

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
}
