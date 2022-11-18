const {ethers} = require('hardhat');
import {expect} from "chai";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {HeliosGlobals, HeliosGlobals__factory} from "../typechain-types";
import "hardhat-gas-reporter";

describe("HeliosGlobals contract", function () {
    let heliosGlobals: HeliosGlobals;
    let owner: SignerWithAddress;
    let admin: SignerWithAddress;
    let admin2: SignerWithAddress;
    let address: SignerWithAddress[];


    beforeEach(async function () {
        [owner, admin, admin2, ...address] = await ethers.getSigners();

        const heliosGlobalsFactory = (await ethers.getContractFactory("HeliosGlobals", owner)) as HeliosGlobals__factory;
        heliosGlobals = await heliosGlobalsFactory.deploy(owner.address, admin.address);
    });

    describe("Protocol Pause", function () {
        it("Should have Paused state", async function () {
            await heliosGlobals.connect(admin).setProtocolPause(true);
            expect(await heliosGlobals.protocolPaused()).to.equal(true);
        });

        it("Should have Un-paused state", async function () {
            await heliosGlobals.connect(admin).setProtocolPause(false);
            expect(await heliosGlobals.protocolPaused()).to.equal(false);
        });

        it("Only Admin can pause/un-pause protocol", async function () {
            await expect(heliosGlobals.connect(owner).setProtocolPause(true))
                .to.be.revertedWith('HG:NOT_ADMIN');
        });
    });

    describe("Global Admin", function () {
        it("Set Valid Pool Factory", async function () {
            await heliosGlobals.setValidPoolFactory(address[0].address, true);
            expect(await heliosGlobals.isValidPoolFactory(address[0].address)).to.equal(true);
            expect(await heliosGlobals.isValidPoolFactory(address[1].address)).to.equal(false);
        });

        it("Set Global Admin Success", async function () {
            await heliosGlobals.setGlobalAdmin(admin2.address);
            expect(await heliosGlobals.globalAdmin()).to.equal(admin2.address);
        });

        it("Set Global Admin when paused Fail", async function () {
            await heliosGlobals.connect(admin).setProtocolPause(true);
            await expect(heliosGlobals.setGlobalAdmin(admin2.address))
                .to.be.revertedWith('HG:PROTO_PAUSED');
        });

        it("Set Global Admin Fail", async function () {
            await expect(heliosGlobals.connect(admin2).setGlobalAdmin(admin2.address))
                .to.be.revertedWith('HG:NOT_GOV_OR_ADMIN');
        });

        it("Set Valid Pool Delegate", async function () {
            await heliosGlobals.setPoolDelegateAllowList(address[0].address, true);
            expect(await heliosGlobals.isValidPoolDelegate(address[0].address)).to.equal(true);
            expect(await heliosGlobals.isValidPoolDelegate(address[1].address)).to.equal(false);
        });
    });
});