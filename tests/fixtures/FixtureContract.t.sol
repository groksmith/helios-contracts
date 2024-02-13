pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockTokenERC20} from "../mocks/MockTokenERC20.sol";
import {HeliosGlobals} from "../../contracts/global/HeliosGlobals.sol";
import {PoolFactory} from "../../contracts/pool/PoolFactory.sol";
import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";
import {Pool} from "../../contracts/pool/Pool.sol";

abstract contract FixtureContract is Test {
    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;
    address public constant USER_ADDRESS = 0x4F8fF72C3A17B571D4a1671d5ddFbcf48187FBCa;

    address internal constant INVESTOR_1 = address(uint160(uint256(keccak256("investor1"))));
    address internal constant INVESTOR_2 = address(uint160(uint256(keccak256("investor2"))));

    HeliosGlobals public heliosGlobals;
    ERC20 public liquidityAsset;
    MockTokenERC20 private liquidityAssetElevated;
    PoolFactory public poolFactory;
    BlendedPool public blendedPool;
    Pool public regPool1;

    function fixture() public {
        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);

        heliosGlobals = new HeliosGlobals(OWNER_ADDRESS);
        liquidityAssetElevated = new MockTokenERC20("USDT", "USDT");
        liquidityAsset = ERC20(liquidityAssetElevated);

        liquidityAssetElevated.mint(OWNER_ADDRESS, 1000000);
        liquidityAssetElevated.mint(USER_ADDRESS, 1000);

        heliosGlobals.setLiquidityAsset(address(liquidityAsset), true);

        poolFactory = new PoolFactory(address(heliosGlobals));
        heliosGlobals.setValidPoolFactory(address(poolFactory), true);

        address poolAddress = poolFactory.createPool(
            "reg pool",
            address(liquidityAsset),
            2000,
            10,
            1000,
            100000,
            100,
            500,
            1000
        );

        regPool1 = Pool(poolAddress);

        assertEq(regPool1.decimals(), liquidityAsset.decimals());

        address blendedPoolAddress = poolFactory.createBlendedPool(
            address(liquidityAsset),
            1000,
            200,
            300,
            100,
            500,
            1000
        );

        blendedPool = BlendedPool(blendedPoolAddress);
        assertEq(blendedPool.decimals(), liquidityAsset.decimals());
        assertEq(poolFactory.getBlendedPool(), address(blendedPool));

        vm.stopPrank();
    }

    function createInvestorAndMintLiquidityAsset(address investor, uint256 amount) public returns (address) {
        vm.assume(investor != address(0));
        vm.assume(investor != OWNER_ADDRESS);
        vm.assume(investor != address(liquidityAsset));
        vm.assume(amount < liquidityAssetElevated.totalSupply());

        liquidityAssetElevated.mint(investor, amount);
        return investor;
    }

    function mintLiquidityAsset(address user, uint256 amount) public {
        liquidityAssetElevated.mint(user, amount);
    }

    function burnLiquidityAsset(address user, uint256 amount) public {
        liquidityAssetElevated.burn(user, amount);
    }

}
