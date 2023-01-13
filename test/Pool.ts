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
        const [owner, admin, borrower] = await ethers.getSigners();
        const {poolContract, IERC20Token} = await loadFixture(createPoolFixture);

        await IERC20Token.approve(poolContract.address, 100);
        await poolContract.deposit(100);

        const liquidityLockerFactory = await ethers.getContractFactory("LiquidityLocker", admin);
        const liquidityLocker = liquidityLockerFactory.attach(await poolContract.liquidityLocker());

        expect(await IERC20Token.balanceOf(liquidityLocker.address)).equal(100);

        await poolContract.connect(admin).setBorrower(borrower.address);

        expect(await IERC20Token.balanceOf(borrower.address)).equal(0);
        await poolContract.connect(borrower).borrow(100);
        expect(await IERC20Token.balanceOf(borrower.address)).equal(100);

        await time.increase(1001);
        await(expect(poolContract.withdraw(5))
            .to.be.revertedWith('P:INSUFF_TRANS_BAL'));
    });
});