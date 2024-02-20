pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {MockTokenERC20} from "../mocks/MockTokenERC20.sol";
import {HeliosGlobals} from "../../contracts/global/HeliosGlobals.sol";
import {Pool} from "../../contracts/pool/Pool.sol";
import {PoolLibrary} from "../../contracts/library/PoolLibrary.sol";
import {PoolFactory} from "../../contracts/pool/PoolFactory.sol";

import {BlendedPoolTestHandler} from "./BlendedPoolTestHandler.t.sol";
import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BlendedPoolInvariantTest is Test {
    BlendedPoolTestHandler private handler;
    BlendedPool private blendedPool;

    ERC20 public asset;
    MockTokenERC20 private assetElevated;
    HeliosGlobals public heliosGlobals;
    PoolFactory public poolFactory;

    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;

    function setUp() external {
        vm.startPrank(OWNER_ADDRESS);

        heliosGlobals = new HeliosGlobals(OWNER_ADDRESS);
        assetElevated = new MockTokenERC20("USDT", "USDT");
        asset = ERC20(assetElevated);

        assetElevated.mint(OWNER_ADDRESS, 1000000);

        heliosGlobals.setAsset(address(asset), true);

        poolFactory = new PoolFactory(address(heliosGlobals));
        heliosGlobals.setPoolFactory(address(poolFactory));

        address blendedPoolAddress = poolFactory.createBlendedPool(
            address(asset),
            300,
            0 // Setting minInvestmentAmount to 0 for testing if this can create larger issues
        );

        blendedPool = BlendedPool(blendedPoolAddress);
        vm.stopPrank();

        handler = new BlendedPoolTestHandler(blendedPool, assetElevated);
        targetContract(address(handler));
    }

    // INVARIANT #1
    // Test that the pool's token balance is equal to:
    //  + total deposits (net of withdrawals)
    //  - the sum of withdrawals
    //  + total of all yield transferred in to the locker
    //  + total borrowed (net of repayments)
    function invariant_liquidity_locker_balance_equals_tracked_deposits() external returns (bool){
        return handler.netInflows() + handler.netYieldAccrued() + handler.netBorrowed() ==
            asset.balanceOf(address(blendedPool)) + blendedPool.principalOut();
    }

    // INVARIANT #2
    // Test that the total deposits (net of withdrawals) is equal to the sum of all user deposit instances
    function invariant_deposit_instances_equal_tracked_deposits() public returns (bool){
        emit LogUint("netDeposits", handler.netDeposits());
        emit LogUint("sumUserDeposits", sumUserDeposits());
        return sumUserDeposits() == handler.netDeposits();
    }

    // INVARIANT #3
    // Test that the total of all deposit instances is equal to the sum of the pool's ERC20 token balances
    function invariant_pool_erc20_equals_tracked_deposits() public returns (bool){
        emit LogUint("sumPoolTokenBalances()", sumPoolTokenBalances());
        emit LogUint("netDeposits", handler.netDeposits());
        return handler.netDeposits() == sumPoolTokenBalances();
    }

    // INVARIANT #4
    // Test that the total of all deposit instances is equal to the sum of the pool's ERC20 token balances
    function invariant_pool_erc20_equals_user_deposits() public returns (bool){
        emit LogUint("sumPoolTokenBalances()", sumPoolTokenBalances());
        emit LogUint("sumUserDeposits", sumUserDeposits());
        return sumUserDeposits() == sumPoolTokenBalances();
    }

    // INVARIANT #5
    // Test that the total of all deposit instances is equal to the pool's totalDeposited storage variable
    function invariant_totalDeposited_equals_tracked_deposits() public returns (bool){
        emit LogUint("blendedPool.totalDeposited()", blendedPool.totalDeposited());
        emit LogUint("netDeposits", handler.netDeposits());
        return blendedPool.totalDeposited() == handler.netDeposits();
    }

    // INVARIANT #6
    // Test that the sum of all user yields is equal to the the sum of all
    // amounts of yield distributed minus the total precision loss
    function invariant_total_yield() external returns (bool){
        return handler.netYieldAccrued() == sumUserYields();
    }

    // INVARIANT #7
    // Test that the sum of all user yields is equal to the the sum of all
    // amounts of yield distributed minus the total precision loss
    function invariant_total_yield_with_precision_loss() external returns (bool){
        return handler.netYieldAccrued() - handler.yieldPrecisionLoss() == sumUserYields();
    }

    // INVARIANT #8
    // Test that the precision loss for yields is less than the sum of total user count minus 1
    // for each time distributeYield is called
    function invariant_yield_precision_loss() external returns (bool){
        return handler.yieldPrecisionLoss() <= handler.maxPrecisionLossForYields();
    }

    event LogUint(string, uint);

    function sumUserDeposits() public view returns (uint sum){
        sum = 0;
        uint holders_count = blendedPool.getHoldersCount();
        for (uint i = 0; i < holders_count; i++) {
            address holder = blendedPool.getHolderByIndex(i);
            sum += blendedPool.totalDepositsAmount(holder);
        }
    }

    function sumPoolTokenBalances() public view returns (uint sum){
        sum = 0;
        for (uint i = 0; i < handler.users().length; i++) {
            sum += blendedPool.balanceOf(handler.users()[i]);
        }
    }

    function sumUserYields() public view returns (uint sum){
        sum = 0;
        for (uint i = 0; i < handler.users().length; i++) {
            sum += blendedPool.yields(handler.users()[i]);
        }
    }

    function assertEqualWithinPrecision(uint x, uint y, uint precision) internal view returns (bool){
        return absDiff(x, y) <= precision;
    }

    function absDiff(uint x, uint y) internal view returns (uint){
        if (x > y) {
            return x - y;
        } else {
            return y - x;
        }
    }
}
