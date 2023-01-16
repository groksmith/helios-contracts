import {loadFixture, mine, time} from "@nomicfoundation/hardhat-network-helpers";
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
        await poolContract.connect(investor2).deposit(50);

        await poolContract.connect(borrower).borrow(150);

        await IERC20Token.connect(borrower).approve(poolContract.address, 300);
        await poolContract.connect(borrower).repay(300);
        await time.increase(1001);

        await poolContract.connect(investor1).withdraw(100);
        const investor1Total = await IERC20Token.balanceOf(investor1.address);
        console.log("investor1Total:", investor1Total);

        await poolContract.connect(investor2).withdraw(50);
        const investor2Total = await IERC20Token.balanceOf(investor2.address);
        console.log("investor2Total:", investor2Total);

        const liquidityLockerAmount = await IERC20Token.balanceOf(liquidityLocker.address);
        console.log("liquidityLockerAmount:", liquidityLockerAmount);
    });
});