import {ethers} from "hardhat";

const POOL_FACTORY_ADDRESS = "0x00900af6eaeE07F8F2ce6B97411542f8d5F568f1";
const USDC_ADDRESS = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";
const POOL_ID = "1ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";

async function main() {
    // Get Signers
    let [owner, admin] = await ethers.getSigners();

    // Get PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", admin);
    const poolFactoryContract = await poolFactoryFactory.attach(POOL_FACTORY_ADDRESS);

    const pool = await poolFactoryContract.pools(POOL_ID);
    const poolFactory = await ethers.getContractFactory("Pool", admin);
    const poolContract = poolFactory.attach(pool);

    //const name = await poolContract.name();
    //await poolContract.finalize();
    //await poolContract.setOpenToPublic(true);

    const IERC20Token = await ethers.getContractAt("IERC20", USDC_ADDRESS, owner);

    const balanceBefore = await IERC20Token.balanceOf(owner.address);

    await poolContract.isDepositAllowed(1);

    await IERC20Token.approve(poolContract.address, 1);
    await poolContract.deposit(1);

    IERC20Token.balanceOf(owner.address).then(console.log);
}

main().catch((error) => {
    console.error(error.error.message);
    process.exitCode = 1;
});

