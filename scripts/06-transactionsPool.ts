import {ethers} from "hardhat";

let POOL_FACTORY_ADDRESS = process.env.POOL_FACTORY_ADDRESS!;
let USDC = process.env.USDC_ADDRESS!;
let POOL_ID = process.env.CONTRACT_POOL!;

async function main() {

    // Get Signers
    let [owner, admin] = await ethers.getSigners();

    // Get PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", admin);
    const poolFactoryContract = await poolFactoryFactory.attach(POOL_FACTORY_ADDRESS);

    const pool = await poolFactoryContract.pools(POOL_ID);
    const poolFactory = await ethers.getContractFactory("Pool", admin);
    const poolContract = poolFactory.attach(pool);

    const USD = 10 ** 6;
    const IERC20Token = await ethers.getContractAt("IERC20", USDC, admin);

    const balanceBefore = await IERC20Token.balanceOf(admin.address);

    await poolContract.isDepositAllowed(1);

    await IERC20Token.approve(poolContract.address, 2);
    await poolContract.withdraw(1);

    const balanceAfter = await IERC20Token.balanceOf(owner.address);
}

main().catch((error) => {
    console.error(error.error.message);
    process.exitCode = 1;
});

