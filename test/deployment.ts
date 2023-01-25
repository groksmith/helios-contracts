import {ethers} from "hardhat";
import {expect} from "chai";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {
    HeliosGlobals,
    HeliosGlobals__factory,
    LiquidityLockerFactory,
    LiquidityLockerFactory__factory,
    Pool,
    Pool__factory,
    PoolFactory,
    PoolFactory__factory
} from "../typechain-types";

const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

export async function deployTokenFixture() {
    let heliosGlobals: HeliosGlobals;
    let poolFactory: PoolFactory;
    let liquidityLockerFactory: LiquidityLockerFactory;
    let owner: SignerWithAddress;
    let admin: SignerWithAddress;
    let admin2: SignerWithAddress;
    let address: SignerWithAddress[]

    [owner, admin, admin2, ...address] = await ethers.getSigners();

    const IERC20Token = await ethers.getContractAt("IERC20Metadata", USDC, owner);

    const heliosGlobalsFactory = (await ethers.getContractFactory("HeliosGlobals", owner)) as HeliosGlobals__factory;
    heliosGlobals = await heliosGlobalsFactory.deploy(owner.address, admin.address);

    await heliosGlobals.setLiquidityAsset(USDC, true);

    const poolFactoryFactory = (await ethers.getContractFactory("PoolFactory", owner)) as PoolFactory__factory;
    poolFactory = await poolFactoryFactory.deploy(heliosGlobals.address);
    expect(await poolFactory.globals()).to.equal(heliosGlobals.address);

    const liquidityLockerFactoryFactory = (await ethers.getContractFactory("LiquidityLockerFactory", owner)) as LiquidityLockerFactory__factory;
    liquidityLockerFactory = await liquidityLockerFactoryFactory.deploy();

    await heliosGlobals.setValidPoolFactory(poolFactory.address, true);
    await heliosGlobals.setValidSubFactory(poolFactory.address, liquidityLockerFactory.address, true);
    await heliosGlobals.setPoolDelegateAllowList(admin.address, true);
    return {heliosGlobals, poolFactory, liquidityLockerFactory, owner, admin, admin2, address, IERC20Token};
}

export async function createPoolFixture() {
    const {
        heliosGlobals,
        poolFactory,
        liquidityLockerFactory,
        admin,
        IERC20Token
    } = await deployTokenFixture();

    await heliosGlobals.setPoolDelegateAllowList(admin.address, true);
    const poolId = "6ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";
    await poolFactory.connect(admin).createPool(
        poolId,
        USDC,
        liquidityLockerFactory.address,
        1000,
        12,
        1000,
        100000,
        100);

    const pool = await poolFactory.pools(poolId);
    const poolContractFactory = await ethers.getContractFactory("Pool") as Pool__factory;
    const poolContract = poolContractFactory.attach(pool);
    await poolContract.connect(admin).finalize();
    return {IERC20Token, poolContract};
}