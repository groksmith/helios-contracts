import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {createPoolFixture} from "./deployment";
import {ethers} from "hardhat";
import {expect} from "chai";

describe("Pool contract", function () {
    it("Pool check", async function () {
        const [owner, admin] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);
        await poolContract.connect(admin).finalize();
        await poolContract.connect(admin).setOpenToPublic(true);

        expect(await poolContract.isDepositAllowed(5)).true;

        const tx = await IERC20Token.approve(poolContract.address, 5);
        await tx.wait(1);
        await poolContract.deposit(5);
    });
});