import {loadFixture, time} from "@nomicfoundation/hardhat-network-helpers";
import {createPoolFixture} from "./deployment";
import {ethers} from "hardhat";
import {expect} from "chai";

describe("Pool Investments", function () {
    it("Pool deposit", async function () {
        const [owner, admin] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        const amountBefore = await IERC20Token.balanceOf(owner.address);

        await IERC20Token.approve(poolContract.address, 100);

        await expect(poolContract.deposit(100))
            .to.emit(poolContract, "BalanceUpdated")
            .and
            .to.emit(poolContract, "CoolDown")
            .withArgs(owner.address, 100);

        await time.increase(1001);
        expect(await IERC20Token.balanceOf(owner.address)).equal(amountBefore.sub(100));

        const liquidityLockerFactory = await ethers.getContractFactory("LiquidityLocker", admin);
        const liquidityLocker = liquidityLockerFactory.attach(await poolContract.liquidityLocker());

        expect(await IERC20Token.balanceOf(liquidityLocker.address)).equal(100);
    });

    it("Pool deposit revert: min deposit amount", async function () {
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await IERC20Token.approve(poolContract.address, 10);
        await (expect(poolContract.deposit(10)))
            .to.be.revertedWith('P:DEP_AMT_BELOW_MIN');
    });

    it("Pool deposit revert: deposit amount exceeds pool size", async function () {
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await IERC20Token.approve(poolContract.address, 130000);
        await (expect(poolContract.deposit(130000)))
            .to.be.revertedWith('P:DEP_AMT_EXCEEDS_POOL_SIZE');
    });

    it("Pool deposit revert: deposit amount exceeds accepted", async function () {
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await IERC20Token.approve(poolContract.address, 10);
        await (expect(poolContract.deposit(100)))
            .to.be.revertedWith('ERC20: transfer amount exceeds allowance');
    });

    it("Pool withdraw", async function () {
        const [, admin] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await IERC20Token.approve(poolContract.address, 100);
        await poolContract.deposit(100);
        await time.increase(1001);
        await expect(poolContract.withdraw(100))
            .to.emit(poolContract, "BalanceUpdated");

        const liquidityLockerFactory = await ethers.getContractFactory("LiquidityLocker", admin);
        const liquidityLocker = liquidityLockerFactory.attach(await poolContract.liquidityLocker());

        expect(await IERC20Token.balanceOf(liquidityLocker.address)).equal(0);
    });

    it("Pool can withdraw", async function () {
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await IERC20Token.approve(poolContract.address, 100);
        await poolContract.deposit(100);

        await (expect(poolContract.canWithdraw(100))
            .to.be.revertedWith('P:FUNDS_LOCKED'));

        await time.increase(1001);
        expect(await poolContract.canWithdraw(100)).true;
    });

    it("Pool withdraw period not reached", async function () {
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await IERC20Token.approve(poolContract.address, 100);
        await poolContract.deposit(100);
        await (expect(poolContract.withdraw(100))
            .to.be.revertedWith('P:FUNDS_LOCKED'));
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