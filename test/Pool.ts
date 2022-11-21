import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";

import {deployTokenFixture} from "./deployment";
import {expect} from "chai";

describe("Pool contract", function () {
    it("Some func", async function () {
        const {poolFactory} = await loadFixture(deployTokenFixture);
        await poolFactory.pause();
        expect(await poolFactory.paused()).to.equal(true);
        await poolFactory.unpause();
        expect(await poolFactory.paused()).to.equal(false);
    });
});