import {ethers} from "hardhat";
import {IERC20Metadata, Pool} from "../typechain-types";
import {BigNumber} from "ethers";

let CONTRACT_POOL_FACTORY = process.env.CONTRACT_POOL_FACTORY!;
let CONTRACT_USDC = process.env.CONTRACT_USDC!;
let POOL_ID = process.env.POOL_ID!;

async function main() {
    const [, admin, , borrower] = await ethers.getSigners();

    // Get PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", admin);
    const poolFactoryContract = await poolFactoryFactory.attach(CONTRACT_POOL_FACTORY);

    const pool = await poolFactoryContract.pools(POOL_ID);
    const poolFactory = await ethers.getContractFactory("Pool", admin);
    const poolContract = poolFactory.attach(pool) as Pool;

    const txSetBorrower = await poolContract.setBorrower(borrower.address);
    await txSetBorrower.wait(1);

    const IERC20Token = await ethers.getContractAt("IERC20Metadata", CONTRACT_USDC, borrower) as IERC20Metadata;
    const decimals = await IERC20Token.decimals();

    const balanceBeforeBN = await IERC20Token.balanceOf(borrower.address);
    const balance = toWad(balanceBeforeBN, decimals);

    const amount = 5 * 10 ** decimals;
    const txDrawdown = await poolContract.connect(borrower).drawdown(amount);
    await txDrawdown.wait(1);

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

