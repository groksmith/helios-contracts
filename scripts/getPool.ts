import {ethers} from "hardhat";

async function main() {
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory");
    const poolFactoryContract = poolFactoryFactory.attach('0x1e6b007Ac14a08e141B996d0398B281B3ecacA59');
    const pool = await poolFactoryContract.pools(0)
    await console.log(pool)

    const poolFactory = await ethers.getContractFactory("Pool");
    const poolContract = poolFactory.attach(pool);

    await console.log(await poolContract.apy())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
