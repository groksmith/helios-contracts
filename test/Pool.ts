import {loadFixture, mine, time} from "@nomicfoundation/hardhat-network-helpers";
import {createPoolFixture} from "./deployment";
import {ethers} from "hardhat";
import {expect} from "chai";

describe("Pool contract", function () {
    it("Pool check", async function () {
        const [owner, admin] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);
        await poolContract.connect(admin).finalize();
        await poolContract.connect(admin).setOpenToPublic(true);

        await poolContract.isDepositAllowed(100);
        IERC20Token.balanceOf(owner.address).then(console.log);

        await IERC20Token.approve(poolContract.address, 100);
        await mine(1);
        await poolContract.deposit(100);
        await time.increase(1000);
        await poolContract.withdraw(10);
        IERC20Token.balanceOf(owner.address).then(console.log);
    });
});