import {ethers} from "hardhat";
import {IERC20Metadata, Pool} from "../typechain-types";
import {BigNumber} from "ethers";

let CONTRACT_POOL_FACTORY = process.env.CONTRACT_POOL_FACTORY!;
let CONTRACT_USDC = process.env.CONTRACT_USDC!;
let POOL_ID = process.env.POOL_ID!;

async function main() {
    const [, , , borrower] = await ethers.getSigners();

    // Get PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", borrower);
    const poolFactoryContract = await poolFactoryFactory.attach(CONTRACT_POOL_FACTORY);

    const pool = await poolFactoryContract.pools(POOL_ID);
    const poolFactory = await ethers.getContractFactory("Pool", borrower);
    const poolContract = poolFactory.attach(pool) as Pool;

    const IERC20Token = await ethers.getContractAt("IERC20Metadata", CONTRACT_USDC, borrower) as IERC20Metadata;
    const decimals = await IERC20Token.decimals();

    const balanceBeforeBN = await IERC20Token.balanceOf(borrower.address);
    const balance = toWad(balanceBeforeBN, decimals);

    const amount = 15 * 10 ** decimals;
    const txApprove = await IERC20Token.approve(poolContract.address, amount);
    await txApprove.wait(1);

    const txMakePayment = await poolContract.connect(borrower).makePayment(amount);
    await txMakePayment.wait(1);

    const balanceAfterBN = await IERC20Token.balanceOf(borrower.address);
    const balanceAfter = toWad(balanceAfterBN, decimals);
}

const toWad = (amount: BigNumber, decimals = 18) => {
    if (!amount) return 0;
    return amount.toNumber() / 10 ** decimals;
}

main().catch((error) => {
    console.error(error.error.message);
    process.exitCode = 1;
});

