import {loadFixture, time} from "@nomicfoundation/hardhat-network-helpers";
import {createPoolFixture} from "./deployment";
import {ethers} from "hardhat";
import {expect} from "chai";

describe("Pool Borrowing", function () {
    it("Pool drawdown", async function () {
        const [, admin, investor, borrower] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await poolContract.connect(admin).setBorrower(borrower.address);

        await IERC20Token.transfer(investor.address, 100);
        await IERC20Token.transfer(borrower.address, 200);

        await IERC20Token.connect(investor).approve(poolContract.address, 100);
        await poolContract.connect(investor).deposit(100);

        await poolContract.connect(borrower).drawdown(100);
    });

    it("Pool drawdown fails insufficient liquidity", async function () {
        const [, admin, borrower] = await ethers.getSigners();
        const {poolContract} = await loadFixture(createPoolFixture);

        await poolContract.connect(admin).setBorrower(borrower.address);

        await (expect(poolContract.connect(borrower).drawdown(200))
            .to.be.revertedWith('P:INSUFFICIENT_LIQUIDITY'));
    });

    it("Pool withdraw funds", async function () {
        const [, admin, investor1, investor2, investor3, borrower] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await poolContract.connect(admin).setBorrower(borrower.address);

        await IERC20Token.transfer(investor1.address, 10000);
        await IERC20Token.transfer(investor2.address, 5000);
        await IERC20Token.transfer(investor3.address, 15000);
        await IERC20Token.transfer(borrower.address, 100000);

        await IERC20Token.connect(investor1).approve(poolContract.address, 10000);
        await poolContract.connect(investor1).deposit(10000);

        await IERC20Token.connect(investor2).approve(poolContract.address, 5000);
        await poolContract.connect(investor2).deposit(5000);

        await IERC20Token.connect(investor3).approve(poolContract.address, 15000);
        await poolContract.connect(investor3).deposit(15000);

        await poolContract.connect(borrower).drawdown(30000);

        await IERC20Token.connect(borrower).approve(poolContract.address, 1000);
        await poolContract.connect(borrower).makePayment(1000);

        await IERC20Token.connect(borrower).approve(poolContract.address, 32000);
        await poolContract.connect(borrower).makePayment(32000);
        await time.increase(1001);

        await poolContract.connect(investor1).withdraw(10000);
        await poolContract.connect(investor1).withdrawFunds();

        await poolContract.connect(investor2).withdraw(5000);
        await poolContract.connect(investor2).withdrawFunds();

        await poolContract.connect(investor3).withdraw(15000);
        await poolContract.connect(investor3).withdrawFunds();
    });

    it("Pool withdraw funds partially", async function () {
        const [, admin, investor1, investor2, investor3, borrower] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await poolContract.connect(admin).setBorrower(borrower.address);

        await IERC20Token.transfer(investor1.address, 50000);
        await IERC20Token.transfer(investor2.address, 35000);
        await IERC20Token.transfer(investor3.address, 15000);
        await IERC20Token.transfer(borrower.address, 110000);

        await IERC20Token.connect(investor1).approve(poolContract.address, 50000);
        await poolContract.connect(investor1).deposit(50000);

        await IERC20Token.connect(investor2).approve(poolContract.address, 35000);
        await poolContract.connect(investor2).deposit(35000);

        await IERC20Token.connect(investor3).approve(poolContract.address, 15000);
        await poolContract.connect(investor3).deposit(15000);

        await poolContract.connect(borrower).drawdown(100000);

        await IERC20Token.connect(borrower).approve(poolContract.address, 110000);
        await poolContract.connect(borrower).makePayment(110000);
        await time.increase(1001);

        await poolContract.connect(investor1).withdraw(50000);
        await poolContract.connect(investor1).withdrawFundsAmount(4999);

        await poolContract.connect(investor2).withdraw(35000);
        await poolContract.connect(investor2).withdrawFundsAmount(3499);

        await poolContract.connect(investor3).withdraw(15000);
        await poolContract.connect(investor3).withdrawFundsAmount(1499);
    });
});