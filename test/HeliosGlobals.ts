import {expect} from "chai";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {deployTokenFixture} from "./deployment";

describe("HeliosGlobals contract", function () {
    describe("Protocol Pause", function () {
        it("Should have Paused state", async function () {
            const {heliosGlobals, admin} = await loadFixture(deployTokenFixture);
            await heliosGlobals.connect(admin).setProtocolPause(true);
            expect(await heliosGlobals.protocolPaused()).to.equal(true);
        });

        it("Should have Un-paused state", async function () {
            const {heliosGlobals, admin} = await loadFixture(deployTokenFixture);

            await heliosGlobals.connect(admin).setProtocolPause(false);
            expect(await heliosGlobals.protocolPaused()).to.equal(false);
        });

        it("Only Admin can pause/un-pause protocol", async function () {
            const {heliosGlobals, owner} = await loadFixture(deployTokenFixture);

            await expect(heliosGlobals.connect(owner).setProtocolPause(true))
                .to.be.revertedWith('HG:NOT_ADM');
        });
    });

    describe("Global Admin", function () {
        it("Set Valid Pool Factory", async function () {
            const {heliosGlobals, address} = await loadFixture(deployTokenFixture);

            await heliosGlobals.setValidPoolFactory(address[0].address, true);
            expect(await heliosGlobals.isValidPoolFactory(address[0].address)).to.equal(true);
            expect(await heliosGlobals.isValidPoolFactory(address[1].address)).to.equal(false);
        });

        it("Set Global Admin Success", async function () {
            const {heliosGlobals, admin2} = await loadFixture(deployTokenFixture);

            expect(await heliosGlobals.globalAdmin()).not.to.equal(admin2.address);
            await heliosGlobals.setGlobalAdmin(admin2.address);
            expect(await heliosGlobals.globalAdmin()).to.equal(admin2.address);
        });

        it("Set Global Admin when paused Fail", async function () {
            const {heliosGlobals, admin, admin2} = await loadFixture(deployTokenFixture);

            await heliosGlobals.connect(admin).setProtocolPause(true);
            await expect(heliosGlobals.setGlobalAdmin(admin2.address))
                .to.be.revertedWith('HG:PROTO_PAUSED');
        });

        it("Set Global Admin Fail", async function () {
            const {heliosGlobals, admin2} = await loadFixture(deployTokenFixture);

            await expect(heliosGlobals.connect(admin2).setGlobalAdmin(admin2.address))
                .to.be.revertedWith('HG:NOT_GOV_OR_ADM');
        });

        it("Set Valid Pool Delegate", async function () {
            const {heliosGlobals, address} = await loadFixture(deployTokenFixture);

            expect(await heliosGlobals.isValidPoolDelegate(address[0].address)).to.equal(false);
            await heliosGlobals.setPoolDelegateAllowList(address[0].address, true);
            expect(await heliosGlobals.isValidPoolDelegate(address[0].address)).to.equal(true);
            expect(await heliosGlobals.isValidPoolDelegate(address[1].address)).to.equal(false);
        });
    });
});