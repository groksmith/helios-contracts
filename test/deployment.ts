import {ethers} from "hardhat";
import {expect} from "chai";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {
    ERC20,
    HeliosGlobals,
    HeliosGlobals__factory, LiquidityLockerFactory,
    LiquidityLockerFactory__factory,
    PoolFactory,
    PoolFactory__factory
} from "../typechain-types";
import {FakeContract, MockContract, smock} from "@defi-wonderland/smock";

export async function deployTokenFixture() {
    let heliosGlobals: HeliosGlobals;
    let poolFactory: PoolFactory;
    let liquidityLockerFactory: LiquidityLockerFactory;
    let owner: SignerWithAddress;
    let admin: SignerWithAddress;
    let admin2: SignerWithAddress;
    let address: SignerWithAddress[]
    let fakeToken: FakeContract<ERC20>;

    [owner, admin, admin2, ...address] = await ethers.getSigners();

    fakeToken = await smock.fake<ERC20>('ERC20');

    const heliosGlobalsFactory = (await ethers.getContractFactory("HeliosGlobals", owner)) as HeliosGlobals__factory;
    heliosGlobals = await heliosGlobalsFactory.deploy(owner.address, admin.address);
    await heliosGlobals.setLiquidityAsset(fakeToken.address, true);

    const poolFactoryFactory = (await ethers.getContractFactory("PoolFactory", owner)) as PoolFactory__factory;
    poolFactory = await poolFactoryFactory.deploy(heliosGlobals.address);
    expect(await poolFactory.globals()).to.equal(heliosGlobals.address);

    const liquidityLockerFactoryFactory = (await ethers.getContractFactory("LiquidityLockerFactory", owner)) as LiquidityLockerFactory__factory;
    liquidityLockerFactory = await liquidityLockerFactoryFactory.deploy();

    return {heliosGlobals, poolFactory, liquidityLockerFactory, owner, admin, admin2, address, fakeToken};
}