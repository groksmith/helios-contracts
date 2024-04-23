pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {MockTokenERC20} from "../mocks/MockTokenERC20.sol";
import {HeliosGlobals} from "../../contracts/global/HeliosGlobals.sol";
import {PoolFactory} from "../../contracts/pool/PoolFactory.sol";

import {BlendedPoolTestHandler} from "./BlendedPoolTestHandler.t.sol";
import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";
import {Pool} from "../../contracts/pool/Pool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BlendedPoolInvariantTest is Test {
    string public constant NAME = "Helios Pool TKN";
    string public constant SYMBOL = "HLS-P";

    BlendedPoolTestHandler private handler;
    BlendedPool private blendedPool;
    Pool private pool;

    ERC20 public asset;
    MockTokenERC20 private assetElevated;
    HeliosGlobals public heliosGlobals;
    PoolFactory public poolFactory;

    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;

    function setUp() external {
        vm.startPrank(OWNER_ADDRESS);

        // Setup contracts
        heliosGlobals = new HeliosGlobals(OWNER_ADDRESS, OWNER_ADDRESS);
        poolFactory = new PoolFactory(address(heliosGlobals));
        assetElevated = new MockTokenERC20("USDC", "USDC");
        asset = ERC20(assetElevated);

        // Setup variables
        heliosGlobals.setAsset(address(asset), true);
        heliosGlobals.setPoolFactory(address(poolFactory));

        address blendedPoolAddress = poolFactory.createBlendedPool(
            {
                _asset: address(asset),
                _lockupPeriod: 300,
                _minInvestmentAmount: 1,
                _tokenName: NAME,
                _tokenSymbol: SYMBOL
            }
        );

        address regionalPoolAddress = poolFactory.createPool(
            {
                _poolId: "pool id",
                _asset: address(asset),
                _lockupPeriod: 300,
                _minInvestmentAmount: 1,
                _investmentPoolSize: type(uint80).max,
                _tokenName: NAME,
                _tokenSymbol: SYMBOL
            }
        );

        blendedPool = BlendedPool(blendedPoolAddress);
        pool = Pool(regionalPoolAddress);

        vm.stopPrank();

        handler = new BlendedPoolTestHandler(blendedPool, pool, assetElevated);
        targetContract(address(handler));
    }

    // Test that the holders count equal depositors count
    function invariant_users_count_greater_or_equal_deposits_count() public {
        assertGe(handler.users().length, blendedPool.getHoldersCount());
    }

    // Test that the pool's token balance is equal to:
    //  + total deposits
    //  - total withdrawals
    //  - total yield withdrawals
    //  + total repaid
    //  - total borrowed
    function invariant_pool_balance_equals_tracked_deposits() public {
        uint256 inBalance = handler.totalInvested() +
                            handler.totalRepaid() +
                            handler.totalYieldsFromRegionalPool();

        uint256 outBalance = handler.totalBorrowed() +
                            handler.totalWithdrawn() +
                            handler.totalYieldWithdrawn() +
                            handler.totalInvestedToRegionalPool();

        uint256 blendedPoolTotalAssets = asset.balanceOf(address(blendedPool));

        assertEq(inBalance - outBalance, blendedPoolTotalAssets);
    }

    // Test that totalSupply >= locked deposits sum
    function invariant_pool_totalSupply_greater_or_equal_locked_deposits() public {
        assertGe(blendedPool.totalSupply(), handler.sumUserLockedTokens());
    }

    // Test that the total of all deposits is equal to the pool's totalSupply
    function invariant_totalSupply_equals_tracked_deposits() public {
        assertEq(blendedPool.totalSupply(), handler.totalInvested() - handler.totalWithdrawn());
    }

    // Test that the total of all deposits is equal to the pool's totalInvested storage variable
    function invariant_totalDeposited_equals_tracked_deposits() public {
        assertGe(blendedPool.totalInvested(), handler.totalInvested());
    }

    // Test that the total of all deposits is equal to the pool's totalInvested storage variable
    function invariant_totalBalance_equals_to_sum_of_rewardBalanceAmount_and_principalBalanceAmount() public {
        assertGe(blendedPool.totalBalance(), blendedPool.principalBalanceAmount() + blendedPool.yieldBalanceAmount());
    }

    // Test that the sum of all user yields is equal to the the sum of all
    // amounts of yield distributed minus the total precision loss
    function invariant_total_yield() external {
        assertEq(handler.totalYieldAccrued() - handler.totalYieldPrecisionLoss(), handler.sumUserYields());
    }

    // Test that yieldPrecisionLoss <= maxPrecisionLossForYields
    function invariant_yield_precision_loss_less_or_equal_max_precision_loss() external {
        assertLe(handler.totalYieldPrecisionLoss(), handler.maxPrecisionLossForYields());
    }
}
