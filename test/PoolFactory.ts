const {ethers} = require('hardhat');
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {expect} from "chai";
import {deployTokenFixture} from "./deployment";
import {HeliosGlobals__factory} from "../typechain-types";

const LIQUID_LOCKER_FACTORY = 1;

describe("PoolFactory contract", function () {
    it("Pause/Un-pause", async function () {
        const {owner, poolFactory} = await loadFixture(deployTokenFixture);
        await poolFactory.pause();
        expect(await poolFactory.paused()).to.equal(true);

        expect(await poolFactory.unpause())
            .to.emit(poolFactory, "Paused")
            .withArgs(1);

        expect(await poolFactory.paused()).to.equal(false);
    });

    it("Should have correct governor", async function () {
        const {poolFactory, admin} = await loadFixture(deployTokenFixture);
        await expect(poolFactory.connect(admin).pause())
            .to.be.revertedWith('PF:NOT_GOV_OR_ADM');
    });

    it("Set new globals", async function () {
        const {heliosGlobals, poolFactory, owner, admin} = await loadFixture(deployTokenFixture);
        const heliosGlobalsFactory = (await ethers.getContractFactory("HeliosGlobals", owner)) as HeliosGlobals__factory;
        const heliosGlobals2 = await heliosGlobalsFactory.deploy(owner.address, admin.address);

        expect(await poolFactory.globals()).not.to.equal(heliosGlobals2.address);
        await poolFactory.setGlobals(heliosGlobals2.address);
        expect(await poolFactory.globals()).to.equal(heliosGlobals2.address);
        expect(await poolFactory.globals()).to.not.equal(heliosGlobals.address);
    });

    it("Set valid Pool Factory", async function () {
        const {heliosGlobals, poolFactory} = await loadFixture(deployTokenFixture);
        expect(await heliosGlobals.isValidPoolFactory(poolFactory.address)).is.true;
        await heliosGlobals.setValidPoolFactory(poolFactory.address, false);
        expect(await heliosGlobals.isValidPoolFactory(poolFactory.address)).is.false;
    });

    it("Set Liquidity Locker Factory", async function () {
        const {heliosGlobals, poolFactory, liquidityLockerFactory} = await loadFixture(deployTokenFixture);
        expect(await heliosGlobals
            .isValidSubFactory(poolFactory.address, liquidityLockerFactory.address, LIQUID_LOCKER_FACTORY))
            .to.equal(true);
    });

    it("Set Pool Factory Admin", async function () {
        const {poolFactory, admin, admin2} = await loadFixture(deployTokenFixture);

        expect(await poolFactory.poolFactoryAdmins(admin2.address)).not.to.equal(true);
        await poolFactory.setPoolFactoryAdmin(admin2.address, true);
        expect(await poolFactory.poolFactoryAdmins(admin2.address)).to.equal(true);

        await poolFactory.setPoolFactoryAdmin(admin.address, false);
        expect(await poolFactory.poolFactoryAdmins(admin.address)).to.equal(false);

        await expect(poolFactory.connect(admin2).setPoolFactoryAdmin(admin.address, false))
            .to.be.revertedWith('PF:NOT_GOV');
    });

    it("Create Pool", async function () {
        const {
            heliosGlobals,
            poolFactory,
            liquidityLockerFactory,
            admin,
            admin2,
            IERC20Token
        } = await loadFixture(deployTokenFixture);
        await heliosGlobals.setPoolDelegateAllowList(admin.address, true);
        const poolId = "6ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";
        await poolFactory.connect(admin).createPool(
            poolId,
            IERC20Token.address,
            liquidityLockerFactory.address,
            10,
            12,
            100,
            1000,
            100);

        await heliosGlobals.setPoolDelegateAllowList(admin2.address, true);
        const poolId2 = "7ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";
        await poolFactory.connect(admin2).createPool(
            poolId2,
            IERC20Token.address,
            liquidityLockerFactory.address,
            10,
            12,
            100000,
            1000,
            100);
    });

    it("Create Pool Fails", async function () {
        const {
            heliosGlobals,
            poolFactory,
            liquidityLockerFactory,
            admin2,
            IERC20Token
        } = await loadFixture(deployTokenFixture);

        const poolId = "6ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";
        await expect(poolFactory.connect(admin2).createPool(
            poolId,
            IERC20Token.address,
            liquidityLockerFactory.address,
            10,
            12,
            100000,
            100,
            100))
            .to.be.revertedWith('PF:NOT_DELEGATE');

        await heliosGlobals.setPoolDelegateAllowList(admin2.address, false);
        const poolId2 = "7ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";
        await expect(poolFactory.connect(admin2).createPool(
            poolId2,
            IERC20Token.address,
            liquidityLockerFactory.address,
            10,
            12,
            100000,
            100,
            100))
            .to.be.revertedWith('PF:NOT_DELEGATE');
    });

    it("Create Pool Fails Paused", async function () {
        const {
            poolFactory,
            liquidityLockerFactory,
            admin,
            IERC20Token
        } = await loadFixture(deployTokenFixture);
        await poolFactory.pause();

        const poolId2 = "7ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";
        await expect(poolFactory.connect(admin).createPool(
            poolId2,
            IERC20Token.address,
            liquidityLockerFactory.address,
            10,
            12,
            100000,
            100,
            100))
            .to.be.revertedWith('Pausable: paused');
    });

    it("Create Pool Fails null Liquidity Locker Factory", async function () {
        const {
            poolFactory,
            liquidityLockerFactory,
            admin
        } = await loadFixture(deployTokenFixture);

        const poolId2 = "7ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";
        await expect(poolFactory
            .connect(admin)
            .createPool(
                poolId2,
                ethers.constants.AddressZero,
                liquidityLockerFactory.address,
                10,
                12,
                100000,
                100,
                100))
            .to.be.revertedWith('P:ZERO_LIQ_ASSET');
    });

    it("Create Pool Fails null liquidity asset", async function () {
        const {
            poolFactory,
            admin,
            IERC20Token
        } = await loadFixture(deployTokenFixture);

        const poolId2 = "7ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";
        await expect(poolFactory
            .connect(admin)
            .createPool(
                poolId2,
                IERC20Token.address,
                ethers.constants.AddressZero,
                10,
                12,
                100000,
                100,
                100))
            .to.be.revertedWith('P:ZERO_LIQ_LOCKER_FACTORY');
    });
});
