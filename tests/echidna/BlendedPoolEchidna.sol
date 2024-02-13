/*
Test contract to use with echidna: https://github.com/crytic/echidna

This contract tests a BlendedPool based on BlendedPoolTest.t.sol.

Run with: echidna ./tests/echidna/BlendedPoolEchidna.sol --contract BlendedPoolEchidna --config echidna.yaml

The contract's constructor sets up the test. The functions under the User Workflow and Admin Workflow
comments expose functions that echidna can call during fuzzing. The final functions under Properties check invariant
properties throughout testing.

echidna.yaml config settings:

codeSize: 0xFFFF
testLimit: 10000000
corpusDir: tests/echidna/corpus
testMode: property
seqLen: 200
*/
pragma solidity 0.8.20;

import {HeliosGlobals} from "../../contracts/global/HeliosGlobals.sol";
import {Pool} from "../../contracts/pool/Pool.sol";
import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";
import {PoolFactory} from "../../contracts/pool/PoolFactory.sol";
import {LiquidityLockerFactory} from "../../contracts/pool/LiquidityLockerFactory.sol";
import {LiquidityLocker} from "../../contracts/pool/LiquidityLocker.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockTokenERC20} from "../mocks/MockTokenERC20.sol";
import {PoolLibrary} from "../../contracts/library/PoolLibrary.sol";
import {DepositsHolder} from "../../contracts/pool/DepositsHolder.sol";

interface IHevm {
    function prank(address) external;
}

/// Echidna BlendedPool test
contract BlendedPoolEchidna {
    address constant HEVM_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    IHevm hevm = IHevm(HEVM_ADDRESS);
    // Based on FixtureContract
    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;
    address[] public USER_ADDRESSES = [
        address(uint160(uint256(keccak256("user1")))),
        address(uint160(uint256(keccak256("user2")))),
        address(uint160(uint256(keccak256("user3")))),
        address(uint160(uint256(keccak256("user4")))),
        address(uint160(uint256(keccak256("user5"))))
    ];

    HeliosGlobals public heliosGlobals;
    ERC20 public liquidityAsset;
    MockTokenERC20 private liquidityAssetElevated;
    PoolFactory public poolFactory;
    BlendedPool public blendedPool;
    LiquidityLockerFactory public liquidityLockerFactory;
    LiquidityLocker public liquidityLockerBlended;

    // Property variables
    uint public netInflows;
    uint public netYieldAccrued;
    uint public netBorrowed;
    uint public netDeposits;

    /// Constructor which sets up test, based on BlendedPoolTest
    constructor(){
        fixture();
        hevm.prank(OWNER_ADDRESS);
        liquidityAsset.approve(address(blendedPool), 1000);
        for (uint i; i < USER_ADDRESSES.length; i++) {
            hevm.prank(USER_ADDRESSES[i]);
            liquidityAsset.approve(address(blendedPool), 1000);
        }
    }

    /// Helps set up test, based on FixtureContract
    function fixture() internal {
        heliosGlobals = new HeliosGlobals(OWNER_ADDRESS);
        liquidityAssetElevated = new MockTokenERC20("USDT", "USDT");
        liquidityAsset = ERC20(liquidityAssetElevated);
        liquidityAssetElevated.mint(OWNER_ADDRESS, 1000000);
        for (uint i = 0; i < USER_ADDRESSES.length; i++) {
            liquidityAssetElevated.mint(USER_ADDRESSES[i], 1000);
        }
        liquidityLockerFactory = new LiquidityLockerFactory();
        hevm.prank(OWNER_ADDRESS);
        heliosGlobals.setValidLiquidityLockerFactory(address(liquidityLockerFactory), true);
        hevm.prank(OWNER_ADDRESS);
        heliosGlobals.setLiquidityAsset(address(liquidityAsset), true);
        poolFactory = new PoolFactory(address(heliosGlobals));
        hevm.prank(OWNER_ADDRESS);
        heliosGlobals.setValidPoolFactory(address(poolFactory), true);
        hevm.prank(OWNER_ADDRESS);
        address blendedPoolAddress = poolFactory.createBlendedPool(
            address(liquidityAsset),
            address(liquidityLockerFactory),
            1000,
            200,
            300,
            0, // Setting minInvestmentAmount to 0 for testing if this can create larger issues
            500,
            1000
        );
        blendedPool = BlendedPool(blendedPoolAddress);
        liquidityLockerBlended = LiquidityLocker(address(blendedPool.liquidityLocker()));
    }

    /*
        HANDLERS - User Workflow
    */

    /// Make a deposit for a user
    function userDeposit(uint amount, uint user_idx) public {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        amount = amount % type(uint80).max;

        if (liquidityAsset.balanceOf(user) < amount) {
            liquidityAssetElevated.mint(user, amount);
        }

        hevm.prank(user);
        liquidityAsset.approve(address(blendedPool), amount);
        hevm.prank(user);
        blendedPool.deposit(amount);
        netInflows += amount;
        netDeposits += amount;
    }

    /// Make a 0 deposit for a user
    function userDepositZero(uint user_idx) public {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        uint amount = 0;

        hevm.prank(user);
        blendedPool.deposit(amount);
    }

    /// Withdraw the first deposit for a user
    function userWithdrawFirst(uint amount, uint user_idx) external {
        uint holderCount = blendedPool.depositsHolder().getHoldersCount();
        if (holderCount == 0) return;

        user_idx = user_idx % holderCount;
        address user = blendedPool.depositsHolder().getHolderByIndex(user_idx);
        PoolLibrary.DepositInstance[] memory user_deposits = blendedPool.depositsHolder().getDepositsByHolder(user);
        if (user_deposits.length == 0) return;
        amount = amount % user_deposits[0].amount;

        uint[] memory amounts = new uint[](1);
        amounts[0] = amount;
        uint16[] memory indices = new uint16[](1);
        indices[0] = 0;

        hevm.prank(user);
        blendedPool.withdraw(amounts, indices);
        netInflows -= amount;
        netDeposits -= amount;
    }

    /// Withdraw the first N deposits for a user
    function userWithdrawFirstNumFull(uint num_deposits, uint user_idx) external {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        DepositsHolder deposits_holder = blendedPool.depositsHolder();
        PoolLibrary.DepositInstance[] memory user_deposits = deposits_holder.getDepositsByHolder(user);
        num_deposits = num_deposits % user_deposits.length;

        uint shares = blendedPool.balanceOf(user);
        if (shares == 0) return;

        uint[] memory amounts = new uint[](num_deposits);
        uint16[] memory indices = new uint16[](num_deposits);
        for (uint16 i = 0; i < num_deposits; i++) {
            indices[i] = i;
            amounts[i] = user_deposits[i].amount;
        }
        uint total_amount = 0;
        for (uint i = 0; i < amounts.length; i++) {
            total_amount += amounts[i];
        }
        hevm.prank(user);
        blendedPool.withdraw(amounts, indices);
        netInflows -= total_amount;
        netDeposits -= total_amount;
    }

    /// Withdraw yield for a user
    function withdrawYield(uint user_idx) external {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        if (netYieldAccrued == 0) return;
        uint user_current_yield = blendedPool.yields(user);
        hevm.prank(user);
        if (blendedPool.withdrawYield()) {
            // withdrawn
            netYieldAccrued -= user_current_yield;
        } else {
            // added to pending yields
        }
    }

    // / Reinvest yield for a user
    function reinvestYield(uint random, uint user_idx) external {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        if (netYieldAccrued == 0) return;
        uint user_yield = blendedPool.yields(user);
        uint amountToReinvest = random % user_yield;
        hevm.prank(user);
        blendedPool.reinvestYield(amountToReinvest);
        netYieldAccrued -= amountToReinvest;
        netInflows += amountToReinvest;
        netDeposits += amountToReinvest;
    }

    /*
        HANDLERS - Admin Workflow
    */

    uint public yieldPrecisionLoss;
    uint public timesDistributeYieldCalled;
    uint public maxPrecisionLossForYields;

    /// Distribute yields
    function distributeYield() external {
        if (netInflows == 0) return;
        timesDistributeYieldCalled++;
        uint startingSumYields = sumUserYields();
        uint newYieldToDistribute = 0.1e18;
        liquidityAssetElevated.mint(address(liquidityLockerBlended), newYieldToDistribute);

        hevm.prank(OWNER_ADDRESS);
        blendedPool.distributeYields(newYieldToDistribute);
        netYieldAccrued += newYieldToDistribute;
        uint actualChangeInUserYields = sumUserYields() - startingSumYields;
        yieldPrecisionLoss += newYieldToDistribute - actualChangeInUserYields;

        // The maximum precision loss for this distribution is the total number of depositors minus 1
        // example: if there are 50 depisitors and the distribution is 100049, there is a precision loss of 49
        maxPrecisionLossForYields += blendedPool.depositsHolder().getHoldersCount() - 1;
    }

    /// Finish pending withdrawal for a user
    function concludePendingWithdrawal(uint user_idx) external {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        uint pendingWithdrawalAmount = blendedPool.pendingWithdrawals(user);
        hevm.prank(OWNER_ADDRESS);
        blendedPool.concludePendingWithdrawal(user);
        netInflows -= pendingWithdrawalAmount;
        netDeposits -= pendingWithdrawalAmount;
    }

    /// Finish pending yield withdrawal for a user
    function concludePendingYield(uint user_idx) external {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        uint pendingYieldAmount = blendedPool.pendingYields(user);
        hevm.prank(OWNER_ADDRESS);
        blendedPool.concludePendingYield(user);
        netYieldAccrued -= pendingYieldAmount;
    }

    /// Borrow money from the deposits
    function borrow(uint amount) external {
        amount = amount % blendedPool.liquidityLockerTotalBalance();
        hevm.prank(OWNER_ADDRESS);
        blendedPool.borrow(OWNER_ADDRESS, amount);
        netInflows -= amount;
        netBorrowed += amount;
    }

    /// Repay netBorrowed money to the pool
    function repay(uint amount) external {
        if (netInflows == 0) {
            return;
        }
        amount = amount % liquidityAsset.balanceOf(OWNER_ADDRESS);
        hevm.prank(OWNER_ADDRESS);
        blendedPool.repay(amount);
        netInflows += amount;
        if (amount > netBorrowed) {
            netBorrowed = 0;
        } else {
            netBorrowed -= amount;
        }
    }

    /*
        Invariants
    */

    // INVARIANT #1
    // Test that the liquidity locker token balance is equal to:
    //  + total deposits (net of withdrawals)
    //  - the sum of withdrawals
    //  + total of all yield transferred in to the locker
    //  + total borrowed (net of repayments)
    function echidna_liquidity_locker_balance_equals_tracked_deposits() external returns (bool){
        return netInflows + netYieldAccrued + netBorrowed == liquidityAsset.balanceOf(address(liquidityLockerBlended)) + blendedPool.principalOut();
    }

    // INVARIANT #2
    // Test that the total deposits (net of withdrawals) is equal to the sum of all user deposit instances
    function echidna_deposit_instances_equal_tracked_deposits() public returns (bool){
        emit LogUint("netDeposits", netDeposits);
        emit LogUint("sumUserDeposits", sumUserDeposits());
        return sumUserDeposits() == netDeposits;
    }

    // INVARIANT #3
    // Test that the total of all deposit instances is equal to the sum of the pool's ERC20 token balances
    function echidna_pool_erc20_equals_tracked_deposits() public returns (bool){
        emit LogUint("sumPoolTokenBalances()", sumPoolTokenBalances());
        emit LogUint("netDeposits", netDeposits);
        return netDeposits == sumPoolTokenBalances();
    }

    // INVARIANT #4
    // Test that the total of all deposit instances is equal to the sum of the pool's ERC20 token balances
    function echidna_pool_erc20_equals_user_deposits() public returns (bool){
        emit LogUint("sumPoolTokenBalances()", sumPoolTokenBalances());
        emit LogUint("sumUserDeposits", sumUserDeposits());
        return sumUserDeposits() == sumPoolTokenBalances();
    }

    // INVARIANT #5
    // Test that the total of all deposit instances is equal to the pool's totalDeposited storage variable
    function echidna_totalDeposited_equals_tracked_deposits() public returns (bool){
        emit LogUint("blendedPool.totalDeposited()", blendedPool.totalDeposited());
        emit LogUint("netDeposits", netDeposits);
        return blendedPool.totalDeposited() == netDeposits;
    }

    // INVARIANT #6
    // Test that the sum of all user yields is equal to the the sum of all
    // amounts of yield distributed minus the total precision loss
    function echidna_total_yield() external returns (bool){
        return netYieldAccrued == sumUserYields();
    }

    // INVARIANT #7
    // Test that the sum of all user yields is equal to the the sum of all
    // amounts of yield distributed minus the total precision loss
    function echidna_total_yield_with_precision_loss() external returns (bool){
        return netYieldAccrued - yieldPrecisionLoss == sumUserYields();
    }

    // INVARIANT #8
    // Test that the precision loss for yields is less than the sum of total user count minus 1
    // for each time distributeYield is called
    function echidna_yield_precision_loss() external returns (bool){
        return yieldPrecisionLoss <= maxPrecisionLossForYields;
    }

    /*
        Utils
    */

    event LogUint(string, uint);

    function sumUserDeposits() public returns (uint sum){
        uint holders_count = blendedPool.depositsHolder().getHoldersCount();
        DepositsHolder deposits_holder = blendedPool.depositsHolder();
        for (uint i = 0; i < holders_count; i++) {
            PoolLibrary.DepositInstance[] memory user_deposits = deposits_holder.getDepositsByHolder(deposits_holder.getHolderByIndex(i));
            for (uint j = 0; j < user_deposits.length; j++) {
                sum += user_deposits[j].amount;
            }
        }
    }

    function sumPoolTokenBalances() public returns (uint sum){
        for (uint i = 0; i < USER_ADDRESSES.length; i++) {
            sum += blendedPool.balanceOf(USER_ADDRESSES[i]);
        }
    }

    function sumUserYields() public returns (uint sum){
        for (uint i = 0; i < USER_ADDRESSES.length; i++) {
            sum += blendedPool.yields(USER_ADDRESSES[i]);
        }
    }


    function assertEqualWithinPrecision(uint x, uint y, uint precision) internal returns (bool){
        return absDiff(x, y) <= precision;
    }

    function absDiff(uint x, uint y) internal returns (uint){
        if (x > y) {
            return x - y;
        } else {
            return y - x;
        }
    }
}