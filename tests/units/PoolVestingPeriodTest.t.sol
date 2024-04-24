pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {PoolVestingPeriod} from "../../contracts/pool/base/PoolVestingPeriod.sol";
import {PoolErrors} from "../../contracts/pool/base/PoolErrors.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";

contract PoolVestingPeriodImpl is PoolVestingPeriod {
    using SafeERC20 for IERC20;

    constructor(
        address _asset,
        uint256 _minInvestmentAmount,
        uint256 _investmentPoolSize,
        uint256 _lockupPeriod,
        string memory _tokenName,
        string memory _tokenSymbol)
    PoolVestingPeriod(_asset, _tokenName, _tokenSymbol) {
        poolInfo = PoolInfo(_lockupPeriod, _minInvestmentAmount, _investmentPoolSize);
    }

    function deposit(address _from, uint256 _amount) public {
        _updateEffectiveDepositDate(_from, _amount);

        _mint(_from, _amount);

        asset.safeTransferFrom(_from, address(this), _amount);
    }
}

contract PoolVestingPeriodTest is Test, FixtureContract, PoolErrors {
    PoolVestingPeriodImpl private poolVestingPeriod;

    function setUp() public {
        fixture();

        vm.startPrank(address(poolFactory), address(poolFactory));
        poolVestingPeriod = new PoolVestingPeriodImpl(
            {
                _asset: address(asset),
                _minInvestmentAmount: 100000000,
                _lockupPeriod: 86400,
                _investmentPoolSize: type(uint80).max,
                _tokenName: NAME,
                _tokenSymbol: SYMBOL
            }
        );
        vm.stopPrank();
    }

    function test_transfer_locked(address user, address user2, uint256 amount) public {
        vm.assume(user != user2);
        vm.assume(user != address(0));
        vm.assume(user != address(poolVestingPeriod));
        vm.assume(user2 != address(0));
        vm.assume(user2 != address(poolVestingPeriod));

        // mint
        uint256 depositAmount = bound(amount, poolVestingPeriod.getPoolInfo().minInvestmentAmount, type(uint80).max);
        mintAsset(user, depositAmount);
        assertEq(asset.balanceOf(user), depositAmount);

        // deposit
        vm.startPrank(user);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user, depositAmount);

        assertEq(poolVestingPeriod.balanceOf(user), depositAmount);
        assertEq(poolVestingPeriod.balanceOf(user2), 0);

        // transfer
        poolVestingPeriod.transfer(user2, depositAmount);
        vm.stopPrank();

        assertEq(poolVestingPeriod.balanceOf(user2), depositAmount);
        assertEq(poolVestingPeriod.unlockedToWithdraw(user), 0);
        assertEq(poolVestingPeriod.unlockedToWithdraw(user2), 0);
        assertEq(poolVestingPeriod.getHolderUnlockDate(user), poolVestingPeriod.getHolderUnlockDate(user2));
    }

    function test_transfer_unlocked(address user, address user2, uint256 amount) public {
        vm.assume(user != user2);
        vm.assume(user != address(0));
        vm.assume(user != address(poolVestingPeriod));
        vm.assume(user2 != address(0));
        vm.assume(user2 != address(poolVestingPeriod));

        // mint
        uint256 depositAmount = bound(amount, poolVestingPeriod.getPoolInfo().minInvestmentAmount, type(uint80).max);
        mintAsset(user, depositAmount);
        assertEq(asset.balanceOf(user), depositAmount);

        // deposit
        vm.startPrank(user);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user, depositAmount);

        assertEq(poolVestingPeriod.balanceOf(user), depositAmount);
        assertEq(poolVestingPeriod.balanceOf(user2), 0);

        // warp
        vm.warp(poolVestingPeriod.getHolderUnlockDate(user) + 1);

        // transfer
        poolVestingPeriod.transfer(user2, depositAmount);
        vm.stopPrank();

        assertEq(poolVestingPeriod.balanceOf(user2), depositAmount);
        assertEq(poolVestingPeriod.unlockedToWithdraw(user), 0);
        assertEq(poolVestingPeriod.unlockedToWithdraw(user2), depositAmount);
        assertEq(poolVestingPeriod.getHolderUnlockDate(user), poolVestingPeriod.getHolderUnlockDate(user2));
    }

    function test_transfer_already_owned(address user, address user2, uint256 amount) public {
        vm.assume(user != user2);
        vm.assume(user != address(0));
        vm.assume(user != address(poolVestingPeriod));
        vm.assume(user2 != address(0));
        vm.assume(user2 != address(poolVestingPeriod));

        // mint
        uint256 depositAmount = bound(amount, poolVestingPeriod.getPoolInfo().minInvestmentAmount, type(uint80).max);

        // deposit 1
        vm.startPrank(user2);
        mintAsset(user2, depositAmount);
        assertEq(asset.balanceOf(user2), depositAmount);

        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user2, depositAmount);
        vm.stopPrank();

        // warp
        vm.warp(poolVestingPeriod.getHolderUnlockDate(user2) + 1);

        // deposit 2
        vm.startPrank(user);
        mintAsset(user, depositAmount);
        assertEq(asset.balanceOf(user), depositAmount);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user, depositAmount);

        assertEq(poolVestingPeriod.balanceOf(user), depositAmount);
        assertEq(poolVestingPeriod.balanceOf(user2), depositAmount);

        // transfer
        poolVestingPeriod.transfer(user2, depositAmount);
        vm.stopPrank();

        assertEq(poolVestingPeriod.balanceOf(user2), depositAmount * 2);
        assertEq(poolVestingPeriod.unlockedToWithdraw(user), 0);
        assertEq(poolVestingPeriod.unlockedToWithdraw(user2), 0);

        assertGe(poolVestingPeriod.getHolderUnlockDate(user), poolVestingPeriod.getHolderUnlockDate(user2));
    }

    function test_get_holders_count(address user, address user2, uint256 amount) public {
        vm.assume(user != user2);
        vm.assume(user != address(0));
        vm.assume(user != address(poolVestingPeriod));
        vm.assume(user2 != address(0));
        vm.assume(user2 != address(poolVestingPeriod));

        // mint
        uint256 depositAmount = bound(amount, poolVestingPeriod.getPoolInfo().minInvestmentAmount, type(uint80).max);
        mintAsset(user, depositAmount);

        assertEq(poolVestingPeriod.getHoldersCount(), 0);

        // deposit
        vm.startPrank(user);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user, depositAmount);

        assertEq(poolVestingPeriod.getHoldersCount(), 1);

        poolVestingPeriod.transfer(user2, depositAmount);
        assertEq(poolVestingPeriod.getHoldersCount(), 2);

        vm.stopPrank();
    }

    function test_get_holders(address user, address user2, uint256 amount) public {
        vm.assume(user != user2);
        vm.assume(user != address(0));
        vm.assume(user2 != address(0));
        vm.assume(user != address(poolVestingPeriod));
        vm.assume(user2 != address(poolVestingPeriod));

        // mint
        uint256 depositAmount = bound(amount, poolVestingPeriod.getPoolInfo().minInvestmentAmount, type(uint80).max);
        mintAsset(user, depositAmount);

        assertEq(poolVestingPeriod.getHolders().length, 0);

        // deposit
        vm.startPrank(user);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user, depositAmount);

        assertEq(poolVestingPeriod.getHolders().length, 1);

        poolVestingPeriod.transfer(user2, depositAmount);

        assertEq(poolVestingPeriod.getHolders().length, 2);

        address[] memory holders = poolVestingPeriod.getHolders();

        assertEq(holders[0], user);
        assertEq(holders[1], user2);
        vm.stopPrank();
    }

    function test_holder_exists(address user, address user2, uint256 amount) public {
        vm.assume(user != user2);
        vm.assume(user != address(0));
        vm.assume(user != address(poolVestingPeriod));
        vm.assume(user2 != address(0));
        vm.assume(user2 != address(poolVestingPeriod));

        // mint
        uint256 depositAmount = bound(amount, poolVestingPeriod.getPoolInfo().minInvestmentAmount, type(uint80).max);
        mintAsset(user, depositAmount);
        mintAsset(user2, depositAmount);

        assertEq(poolVestingPeriod.holderExists(user), false);

        // deposit
        vm.startPrank(user);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user, depositAmount);
        vm.stopPrank();

        assertEq(poolVestingPeriod.holderExists(user), true);

        // deposit 2
        vm.startPrank(user2);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user2, depositAmount);

        assertEq(poolVestingPeriod.holderExists(user2), true);

        address buyer = vm.addr(uint256(keccak256(bytes("Buyer"))));
        poolVestingPeriod.transfer(buyer, depositAmount);

        assertEq(poolVestingPeriod.holderExists(buyer), true);

        assertEq(poolVestingPeriod.holderExists(OWNER_ADDRESS), false);

        vm.stopPrank();
    }

    function test_get_holder_by_index(address user, address user2, uint256 amount) public {
        vm.assume(user != user2);
        vm.assume(user != address(0));
        vm.assume(user != address(poolVestingPeriod));
        vm.assume(user2 != address(0));
        vm.assume(user2 != address(poolVestingPeriod));

        // mint
        uint256 depositAmount = bound(amount, poolVestingPeriod.getPoolInfo().minInvestmentAmount, type(uint80).max);
        mintAsset(user, depositAmount);
        mintAsset(user2, depositAmount);

        assertEq(poolVestingPeriod.holderExists(user), false);

        // deposit
        vm.startPrank(user);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user, depositAmount);
        vm.stopPrank();

        assertEq(poolVestingPeriod.getHolderByIndex(0), user);

        // deposit 2
        vm.startPrank(user2);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user2, depositAmount);

        assertEq(poolVestingPeriod.getHolderByIndex(1), user2);

        address buyer = vm.addr(uint256(keccak256(bytes("Buyer"))));
        poolVestingPeriod.transfer(buyer, depositAmount);

        assertEq(poolVestingPeriod.getHolderByIndex(2), buyer);

        vm.expectRevert(InvalidIndex.selector);
        poolVestingPeriod.getHolderByIndex(3);

        vm.stopPrank();
    }

    function test_get_holder_unlock_date(address user, uint256 amount) public {
        vm.assume(user != address(0));
        vm.assume(user != address(poolVestingPeriod));

        // mint
        uint256 depositAmount = bound(amount, poolVestingPeriod.getPoolInfo().minInvestmentAmount, type(uint80).max);
        mintAsset(user, depositAmount);

        // deposit
        vm.startPrank(user);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user, depositAmount);
        vm.stopPrank();

        assertEq(poolVestingPeriod.getHolderUnlockDate(user), block.timestamp + poolVestingPeriod.getPoolInfo().lockupPeriod);
    }

    function test_unlocked_to_withdraw(address user, uint256 amount) public {
        vm.assume(user != address(0));
        vm.assume(user != address(poolVestingPeriod));

        // mint
        uint256 depositAmount = bound(amount, poolVestingPeriod.getPoolInfo().minInvestmentAmount, type(uint80).max);
        mintAsset(user, depositAmount);

        // deposit
        vm.startPrank(user);
        asset.approve(address(poolVestingPeriod), depositAmount);
        poolVestingPeriod.deposit(user, depositAmount);
        vm.stopPrank();

        assertEq(poolVestingPeriod.unlockedToWithdraw(user), 0);

        vm.warp(poolVestingPeriod.getHolderUnlockDate(user) + 1);

        assertEq(poolVestingPeriod.unlockedToWithdraw(user), depositAmount);
    }

    function test_calculate_effective_deposit_date(uint80 amountFrom, uint80 dateFrom, uint80 amountTo, uint80 dateTo) public {
        uint256 effectiveDate = poolVestingPeriod.calculateEffectiveDepositDate(amountFrom, dateFrom, amountTo, dateTo);
        if (dateFrom > dateTo)
        {
            assertGe(effectiveDate, dateTo);
            assertLe(effectiveDate, dateFrom);
        }
        else
        {
            assertLe(effectiveDate, dateTo);
            assertGe(effectiveDate, dateFrom);
        }
    }
}