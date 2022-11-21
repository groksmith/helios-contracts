import {ethers} from "hardhat";
import {expect} from "chai";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {HeliosGlobals, HeliosGlobals__factory, PoolFactory, PoolFactory__factory} from "../typechain-types";

export async function deployTokenFixture() {
    let heliosGlobals: HeliosGlobals;
    let poolFactory: PoolFactory;
    let owner: SignerWithAddress;
    let admin: SignerWithAddress;
    let admin2: SignerWithAddress;
    let address: SignerWithAddress[];

    [owner, admin, admin2, ...address] = await ethers.getSigners();

    const heliosGlobalsFactory = (await ethers.getContractFactory("HeliosGlobals", owner)) as HeliosGlobals__factory;
    heliosGlobals = await heliosGlobalsFactory.deploy(owner.address, admin.address);

    const poolFactoryFactory = (await ethers.getContractFactory("PoolFactory", owner)) as PoolFactory__factory;
    poolFactory = await poolFactoryFactory.deploy(heliosGlobals.address);
    expect(await poolFactory.globals()).to.equal(heliosGlobals.address);

    return {heliosGlobals, poolFactory, owner, admin, admin2, address};
}