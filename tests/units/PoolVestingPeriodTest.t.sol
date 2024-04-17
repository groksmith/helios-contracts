pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {PoolVestingPeriod} from "../../contracts/pool/base/PoolVestingPeriod.sol";
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

contract PoolVestingPeriodTest is Test, FixtureContract {
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


    function test_transfer() public {
    }

    function test_transfer_from() public {
    }

    function test_get_holders_count() public {

    }

    function test_get_holders() public {
    }

    function test_holder_exists() public {
    }

    function test_get_holder_by_index() public {
    }

    function test_get_holder_unlock_date() public {
    }

    function test_unlocked_to_withdraw() public {
    }
}