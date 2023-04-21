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
            .to.emit(poolContract, "BalanceUpdated");

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
        await poolContract.withdraw(100);

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
});