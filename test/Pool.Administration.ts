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

        await expect(await poolContract.connect(admin).setPoolAdmin(newAdmin.address, false))
            .to.emit(poolContract, "PoolAdminSet")
            .withArgs(newAdmin.address, false);

        expect(await poolContract.poolAdmins(newAdmin.address)).false;

    });

    it("Pool set borrower", async function () {
        const [, admin, borrower] = await ethers.getSigners();
        const {poolContract} = await loadFixture(createPoolFixture);

        await expect(poolContract.connect(admin).setBorrower(borrower.address))
            .to.emit(poolContract, "BorrowerSet")
            .withArgs(borrower.address);

        expect(await poolContract.borrower()).be.equal(borrower.address);
    });

    it("Pool set invalid borrower", async function () {
        const [, admin, borrower] = await ethers.getSigners();
        const {poolContract} = await loadFixture(createPoolFixture);

        await expect(poolContract.connect(admin).setBorrower(ethers.constants.AddressZero))
            .revertedWith("P:ZERO_BORROWER");

        expect(await poolContract.borrower()).not.to.be.equal(borrower.address);
    });
});