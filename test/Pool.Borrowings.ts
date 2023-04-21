import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {createBorrowerFixture} from "./deployment";
import {expect} from "chai";

describe("Pool Borrowing", async function () {
    it("Pool drawdown", async function () {
        const {poolContract, IERC20Token, investor, borrower} = await loadFixture(createBorrowerFixture);
        await IERC20Token.transfer(investor.address, 100);
        await IERC20Token.transfer(borrower.address, 200);

        await IERC20Token.connect(investor).approve(poolContract.address, 100);
        await poolContract.connect(investor).deposit(100);

        await expect(poolContract.connect(borrower).drawdown(100))
            .to.emit(poolContract, "Drawdown")
            .withArgs(borrower.address, 100, 100);
    });

    it("Pool drawdown fails insufficient liquidity", async function () {
        const {poolContract, borrower} = await loadFixture(createBorrowerFixture);
        await (expect(poolContract.connect(borrower).drawdown(200))
            .to.be.revertedWith('P:INSUFFICIENT_LIQUIDITY'));
    });

    it("Pool make payment principal", async function () {
        const {poolContract, IERC20Token, investor, borrower} = await loadFixture(createBorrowerFixture);
        await IERC20Token.transfer(investor.address, 1000);

        await IERC20Token.connect(investor).approve(poolContract.address, 1000);
        await poolContract.connect(investor).deposit(1000);

        await poolContract.connect(borrower).drawdown(1000);

        await IERC20Token.connect(borrower).approve(poolContract.address, 1000);
        await expect(poolContract.connect(borrower).makePayment(1000))
            .to.emit(poolContract, "Payment")
            .withArgs(borrower.address, 1000, 0);
    });

    it("Pool make payment with interest", async function () {
        const {poolContract, IERC20Token, investor, borrower} = await loadFixture(createBorrowerFixture);
        await IERC20Token.transfer(investor.address, 1000);
        await IERC20Token.connect(investor).approve(poolContract.address, 1000);
        await poolContract.connect(investor).deposit(1000);

        await poolContract.connect(borrower).drawdown(1000);

        await IERC20Token.transfer(borrower.address, 100);
        await IERC20Token.connect(borrower).approve(poolContract.address, 1100);

        await expect(poolContract.connect(borrower).makePayment(1100))
            .to.emit(poolContract, "Payment")
            .withArgs(borrower.address, 1000, 100);

        expect(await poolContract.principalOut()).equal(0);
    });

    it("Pool make payment less than principalOut", async function () {
        const {poolContract, IERC20Token, investor, borrower} = await loadFixture(createBorrowerFixture);

        await IERC20Token.transfer(investor.address, 1000);
        await IERC20Token.connect(investor).approve(poolContract.address, 1000);
        await poolContract.connect(investor).deposit(1000);

        await poolContract.connect(borrower).drawdown(1000);

        await IERC20Token.connect(borrower).approve(poolContract.address, 700);
        await expect(poolContract.connect(borrower).makePayment(700))
            .to.emit(poolContract, "Payment")
            .withArgs(borrower.address, 700, 0);

        expect(await poolContract.principalOut()).equal(300);
    });
});