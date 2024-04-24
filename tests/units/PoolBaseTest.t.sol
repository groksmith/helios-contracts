pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {PoolBase} from "../../contracts/pool/base/PoolBase.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";

contract PoolBaseImpl is PoolBase
{
    constructor(
        address _asset,
        uint256 _minInvestmentAmount,
        uint256 _investmentPoolSize,
        uint256 _lockupPeriod,
        string memory _tokenName,
        string memory _tokenSymbol)
    PoolBase(_asset, _tokenName, _tokenSymbol) {
        poolInfo = PoolInfo(_lockupPeriod, _minInvestmentAmount, _investmentPoolSize);
    }
}

contract PoolBaseTest is Test, FixtureContract {
    PoolBaseImpl private poolBase;

    function setUp() public {
        fixture();

        vm.startPrank(address(poolFactory), address(poolFactory));
        poolBase = new PoolBaseImpl(
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


    function test_decimals() public {
        assertEq(poolBase.decimals(), 6);
    }

    function test_get_pool_info() public {
        assertEq(poolBase.getPoolInfo().investmentPoolSize, type(uint80).max);
        assertEq(poolBase.getPoolInfo().lockupPeriod, 86400);
        assertEq(poolBase.getPoolInfo().minInvestmentAmount, 100000000);
    }

    function test_total_balance(address user, uint256 amount) public {
        createInvestorAndMintAsset(user, amount);

        vm.startPrank(user);
        asset.approve(address(poolBase), amount);
        asset.transfer(address(poolBase), amount);
        assertEq(poolBase.totalBalance(), amount);
        vm.stopPrank();
    }
}