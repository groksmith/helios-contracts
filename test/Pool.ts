import {loadFixture, time} from "@nomicfoundation/hardhat-network-helpers";
import {createPoolFixture} from "./deployment";
import {ethers} from "hardhat";
import {expect} from "chai";

describe("Pool contract", function () {
    it("Pool deposit", async function () {
        const [owner, admin] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        const amountBefore = await IERC20Token.balanceOf(owner.address);
        await IERC20Token.approve(poolContract.address, 100);
        await poolContract.deposit(100);
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

        await IERC20Token.approve(poolContract.address, 10000);
        await (expect(poolContract.deposit(10000)))
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
        await poolContract.withdraw(100);

        const liquidityLockerFactory = await ethers.getContractFactory("LiquidityLocker", admin);
        const liquidityLocker = liquidityLockerFactory.attach(await poolContract.liquidityLocker());

        expect(await IERC20Token.balanceOf(liquidityLocker.address)).equal(0);
    });

    it("Pool withdraw period not reached", async function () {
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await IERC20Token.approve(poolContract.address, 100);
        await poolContract.deposit(100);
        await(expect(poolContract.withdraw(100))
            .to.be.revertedWith('P:FUNDS_LOCKED'));
    });

    it("Pool borrow", async function () {
        const [, admin, investor, borrower] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        const liquidityLockerFactory = await ethers.getContractFactory("LiquidityLocker", admin);
        const liquidityLocker = liquidityLockerFactory.attach(await poolContract.liquidityLocker());

        await poolContract.connect(admin).setBorrower(borrower.address);

        await IERC20Token.transfer(investor.address, 100);
        await IERC20Token.transfer(borrower.address, 200);

        await IERC20Token.connect(investor).approve(poolContract.address, 100);
        await poolContract.connect(investor).deposit(100);

        await poolContract.connect(borrower).drawdown(100);

        await IERC20Token.connect(borrower).approve(poolContract.address, 120);
        await poolContract.connect(borrower).makePayment(120);
        await time.increase(1001);

        await poolContract.connect(investor).withdraw(100);
        await poolContract.connect(investor).withdrawFunds();

        const investorTotal = await IERC20Token.balanceOf(investor.address);
        console.log("investorTotal:", investorTotal);

        const liquidityLockerAmount = await IERC20Token.balanceOf(liquidityLocker.address);
        console.log("liquidityLockerAmount:", liquidityLockerAmount);
    });

    /*
    it("Pool borrow", async function () {
        const [, admin, investor1, investor2, borrower] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        const liquidityLockerFactory = await ethers.getContractFactory("LiquidityLocker", admin);
        const liquidityLocker = liquidityLockerFactory.attach(await poolContract.liquidityLocker());

        await poolContract.connect(admin).setBorrower(borrower.address);

        await IERC20Token.transfer(investor1.address, 100);
        await IERC20Token.transfer(investor2.address, 100);
        await IERC20Token.transfer(borrower.address, 1000);

        await IERC20Token.connect(investor1).approve(poolContract.address, 100);
        await poolContract.connect(investor1).deposit(100);

        await IERC20Token.connect(investor2).approve(poolContract.address, 100);
        await poolContract.connect(investor2).deposit(100);

        await poolContract.connect(borrower).drawdown(200);

        await IERC20Token.connect(borrower).approve(poolContract.address, 220);
        await poolContract.connect(borrower).makePayment(220);
        await time.increase(1001);

        await poolContract.connect(investor1).withdraw(100);
        await poolContract.connect(investor1).withdrawFunds();

        await poolContract.connect(investor2).withdraw(100);
        await poolContract.connect(investor2).withdrawFunds();

        const investor1Total = await IERC20Token.balanceOf(investor1.address);
        console.log("investor1Total:", investor1Total);

        const investor2Total = await IERC20Token.balanceOf(investor2.address);
        console.log("investor2Total:", investor2Total);

        const liquidityLockerAmount = await IERC20Token.balanceOf(liquidityLocker.address);
        console.log("liquidityLockerAmount:", liquidityLockerAmount);
    });
    */
});