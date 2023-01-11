import {ethers} from "hardhat";
import {IERC20Metadata} from "../typechain-types";
import {BigNumber} from "ethers";

let CONTRACT_POOL_FACTORY = process.env.CONTRACT_POOL_FACTORY!;
let CONTRACT_USDC = process.env.CONTRACT_USDC!;
let POOL_ID = process.env.POOL_ID!;

async function main() {
    const [owner, admin] = await ethers.getSigners();

    // Get PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", admin);
    const poolFactoryContract = await poolFactoryFactory.attach(CONTRACT_POOL_FACTORY);

    const pool = await poolFactoryContract.pools(POOL_ID);
    const poolFactory = await ethers.getContractFactory("Pool", admin);
    const poolContract = poolFactory.attach(pool);

    const IERC20Token = await ethers.getContractAt("IERC20Metadata", CONTRACT_USDC, admin) as IERC20Metadata;
    const decimals = await IERC20Token.decimals();

    const balanceBeforeBN = await IERC20Token.balanceOf(admin.address);
    const balance = toWad(balanceBeforeBN, decimals);

    await poolContract.isDepositAllowed(2);

    await IERC20Token.approve(poolContract.address, 2);
    await poolContract.deposit(2);

    const balanceAfterBN = await IERC20Token.balanceOf(admin.address);
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

