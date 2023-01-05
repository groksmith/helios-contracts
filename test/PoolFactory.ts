import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {expect} from "chai";
import {HeliosGlobals__factory} from "../typechain-types";
import {deployTokenFixture} from "./deployment";
import {UuidTool} from "uuid-tool";

const {ethers} = require('hardhat');

describe("PoolFactory contract", function () {
    it("Pause/Un-pause", async function () {
        const {poolFactory} = await loadFixture(deployTokenFixture);
        await poolFactory.pause();
        expect(await poolFactory.paused()).to.equal(true);
        await poolFactory.unpause();
        expect(await poolFactory.paused()).to.equal(false);
    });

    it("Should have correct governor", async function () {
        const {poolFactory, admin} = await loadFixture(deployTokenFixture);
        await expect(poolFactory.connect(admin).pause())
            .to.be.revertedWith('PF:NOT_GOV_OR_ADMIN');
    });

    it("Set new globals", async function () {
        const {heliosGlobals, poolFactory, owner, admin} = await loadFixture(deployTokenFixture);
        const heliosGlobalsFactory = (await ethers.getContractFactory("HeliosGlobals", owner)) as HeliosGlobals__factory;
        const heliosGlobals2 = await heliosGlobalsFactory.deploy(owner.address, admin.address);

        await poolFactory.setGlobals(heliosGlobals2.address);
        expect(await poolFactory.globals()).to.equal(heliosGlobals2.address);
        expect(await poolFactory.globals()).to.not.equal(heliosGlobals.address);
    });

    it("Set valid Pool Factory", async function () {
        const {heliosGlobals, poolFactory, owner, admin} = await loadFixture(deployTokenFixture);
        expect(await heliosGlobals.isValidPoolFactory(poolFactory.address)).is.false;
        await heliosGlobals.setValidPoolFactory(poolFactory.address, true);
        expect(await heliosGlobals.isValidPoolFactory(poolFactory.address)).is.true;
    });

    it("Set Liquidity Locker Factory", async function () {
        const {heliosGlobals, poolFactory, liquidityLockerFactory} = await loadFixture(deployTokenFixture);
        await heliosGlobals.setValidPoolFactory(poolFactory.address, true);
        await heliosGlobals.setValidSubFactory(poolFactory.address, liquidityLockerFactory.address, true);
        expect(await heliosGlobals.isValidSubFactory(poolFactory.address, liquidityLockerFactory.address, 3)).to.equal(true);
    });

    it("Set Pool factory Admin", async function () {
        const {poolFactory, admin, admin2} = await loadFixture(deployTokenFixture);
        await poolFactory.setPoolFactoryAdmin(admin2.address, true);
        expect(await poolFactory.poolFactoryAdmins(admin2.address)).to.equal(true);

        await poolFactory.setPoolFactoryAdmin(admin.address, false);
        expect(await poolFactory.poolFactoryAdmins(admin.address)).to.equal(false);

        await expect(poolFactory.connect(admin2).setPoolFactoryAdmin(admin.address, false))
            .to.be.revertedWith('PF:NOT_GOV');
    });

    it("Create Pool", async function () {
        const {heliosGlobals, poolFactory, liquidityLockerFactory, admin, admin2, fakeToken} = await loadFixture(deployTokenFixture);
        await heliosGlobals.setValidPoolFactory(poolFactory.address, true);
        await heliosGlobals.setValidSubFactory(poolFactory.address, liquidityLockerFactory.address, true);

        await heliosGlobals.setPoolDelegateAllowList(admin.address, true);
        const poolId = UuidTool.toBytes('6ec0bd7f-11c0-43da-975e-2a8ad9ebae0b');
        await poolFactory.connect(admin).createPool(poolId, fakeToken.address, liquidityLockerFactory.address,10, 12, 100, 1000, 100);

        await heliosGlobals.setPoolDelegateAllowList(admin2.address, true);
        const poolId2 = UuidTool.toBytes('7ec0bd7f-11c0-43da-975e-2a8ad9ebae0b');
        await poolFactory.connect(admin2).createPool(poolId2, fakeToken.address, liquidityLockerFactory.address, 10, 12, 100000, 1000, 100);
    });

    it("Create Pool Fails", async function () {
        const {heliosGlobals, poolFactory, liquidityLockerFactory, admin2, fakeToken} = await loadFixture(deployTokenFixture);
        const poolId = UuidTool.toBytes('6ec0bd7f-11c0-43da-975e-2a8ad9ebae0b');
        await expect(poolFactory.connect(admin2).createPool(poolId, fakeToken.address, liquidityLockerFactory.address, 10, 12, 100000, 100, 100))
            .to.be.revertedWith('PF:NOT_DELEGATE');

        await heliosGlobals.setPoolDelegateAllowList(admin2.address, false);
        const poolId2 = UuidTool.toBytes('7ec0bd7f-11c0-43da-975e-2a8ad9ebae0b');
        await expect(poolFactory.connect(admin2).createPool(poolId2, fakeToken.address, liquidityLockerFactory.address, 10, 12, 100000, 100, 100))
            .to.be.revertedWith('PF:NOT_DELEGATE');
    });

    it("Create Pool Fails Paused", async function () {
        const {heliosGlobals, poolFactory, liquidityLockerFactory, admin, fakeToken} = await loadFixture(deployTokenFixture);
        await poolFactory.pause();
        await heliosGlobals.setPoolDelegateAllowList(admin.address, true);
        const poolId = UuidTool.toBytes('6ec0bd7f-11c0-43da-975e-2a8ad9ebae0b');
        await expect(poolFactory.connect(admin).createPool(poolId, fakeToken.address, liquidityLockerFactory.address, 10, 12, 100000, 100, 100))
            .to.be.revertedWith('Pausable: paused');
    });
});