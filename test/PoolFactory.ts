const {ethers} = require('hardhat');
import {expect} from "chai";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {
    HeliosGlobals,
    HeliosGlobals__factory,
    PoolFactory,
    PoolFactory__factory
} from "../typechain-types";

import "hardhat-gas-reporter";

describe("PoolFactory contract", function () {
    let heliosGlobals: HeliosGlobals;
    let poolFactory: PoolFactory;
    let owner: SignerWithAddress;
    let admin: SignerWithAddress;
    let admin2: SignerWithAddress;
    let address: SignerWithAddress[];

    beforeEach(async function () {
        [owner, admin, admin2, ...address] = await ethers.getSigners();

        const heliosGlobalsFactory = (await ethers.getContractFactory("HeliosGlobals", owner)) as HeliosGlobals__factory;
        heliosGlobals = await heliosGlobalsFactory.deploy(owner.address, admin.address);

        const poolFactoryFactory = (await ethers.getContractFactory("PoolFactory", owner)) as PoolFactory__factory;
        poolFactory = await poolFactoryFactory.deploy(heliosGlobals.address);
        expect(await poolFactory.globals()).to.equal(heliosGlobals.address);
    });

    describe("PoolFactory", function () {
        it("Pause/Un-pause", async function () {
            await poolFactory.pause();
            expect(await poolFactory.paused()).to.equal(true);
            await poolFactory.unpause();
            expect(await poolFactory.paused()).to.equal(false);
        });

        it("Should have correct governor", async function () {
            await expect(poolFactory.connect(admin).pause())
                .to.be.revertedWith('PF:NOT_GOV_OR_ADMIN');
        });

        it("Set new globals", async function () {
            const heliosGlobalsFactory = (await ethers.getContractFactory("HeliosGlobals", owner)) as HeliosGlobals__factory;
            const heliosGlobals2 = await heliosGlobalsFactory.deploy(owner.address, admin.address);

            await poolFactory.setGlobals(heliosGlobals2.address);
            expect(await poolFactory.globals()).to.equal(heliosGlobals2.address);
            expect(await poolFactory.globals()).to.not.equal(heliosGlobals.address);
        });

        it("Set Pool factory Admin", async function () {
            await poolFactory.setPoolFactoryAdmin(admin2.address, true);
            expect(await poolFactory.poolFactoryAdmins(admin2.address)).to.equal(true);

            await poolFactory.setPoolFactoryAdmin(admin.address, false);
            expect(await poolFactory.poolFactoryAdmins(admin.address)).to.equal(false);

            await expect(poolFactory.connect(admin2).setPoolFactoryAdmin(admin.address, false))
                .to.be.revertedWith('PF:NOT_GOV');
        });

        it("Create Pool", async function () {
            await heliosGlobals.setPoolDelegateAllowList(admin.address, true);
            await poolFactory.connect(admin).createPool(10, 12, 100000, 1);

            await heliosGlobals.setPoolDelegateAllowList(admin2.address, true);
            await poolFactory.connect(admin2).createPool(10, 12, 100000, 1);
        });

        it("Create Pool Fails", async function () {
            await expect(poolFactory.connect(admin2).createPool(10, 12, 100000, 1))
                .to.be.revertedWith('PF:NOT_DELEGATE');

            await heliosGlobals.setPoolDelegateAllowList(admin2.address, false);
            await expect(poolFactory.connect(admin2).createPool(10, 12, 100000, 1))
                .to.be.revertedWith('PF:NOT_DELEGATE');
        });

        it("Create Pool Fails Paused", async function () {
            await poolFactory.pause();
            await heliosGlobals.setPoolDelegateAllowList(admin.address, true);
            await expect(poolFactory.connect(admin).createPool(10, 12, 100000, 1))
                .to.be.revertedWith('Pausable: paused');
        });

        it("Create Pool with valid", async function () {
            await heliosGlobals.setPoolDelegateAllowList(admin.address, true);
            await poolFactory.connect(admin).createPool(10, 12, 100000, 1);
        });
    });
});