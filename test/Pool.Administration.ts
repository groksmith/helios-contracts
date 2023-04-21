import {loadFixture, time} from "@nomicfoundation/hardhat-network-helpers";
import {createPoolFixture} from "./deployment";
import {ethers} from "hardhat";
import {expect} from "chai";

describe("Pool Administration", function () {
    it("Pool deactivate", async function () {
        const [, admin] = await ethers.getSigners();
        const {poolContract} = await loadFixture(createPoolFixture);

        expect(await poolContract.poolState()).equal(1);

        await expect(poolContract.connect(admin).deactivate())
            .to.emit(poolContract, "PoolStateChanged")
            .withArgs(2);

        // Expect PoolState: 2 = Deactivated
        expect(await poolContract.poolState()).equal(2);
    });

    it("Pool decimals", async function () {
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        const decimals = await IERC20Token.decimals();
        const tokenDecimals = await poolContract.decimals();
        expect(decimals).equal(tokenDecimals);
    });

    it("Pool Set new Admin", async function () {
        const [, admin, newAdmin] = await ethers.getSigners();
        const {poolContract} = await loadFixture(createPoolFixture);

        expect(await poolContract.poolAdmins(newAdmin.address)).false;

        await expect(await poolContract.connect(admin).setPoolAdmin(newAdmin.address, true))
            .to.emit(poolContract, "PoolAdminSet")
            .withArgs(newAdmin.address, true);

        expect(await poolContract.poolAdmins(newAdmin.address)).true;
    });
});