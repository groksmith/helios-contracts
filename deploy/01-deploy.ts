import {DeployFunction} from 'hardhat-deploy/types';
import {HeliosGlobals, LiquidityLockerFactory, PoolFactory} from "../typechain-types";

const func: DeployFunction = async function ({getNamedAccounts, deployments}) {
    const {deploy} = deployments;
    const {owner, admin} = await getNamedAccounts();

    const heliosGlobalDeployment = await deploy("HeliosGlobals", {
        from: owner,
        args: [owner, admin],
        log: true,
    });

    await deploy("PoolFactory", {
        from: owner,
        args: [heliosGlobalDeployment.address],
        log: true,
    });

    await deploy("LiquidityLockerFactory", {
        from: owner,
        args: [],
        log: true,
    });
};
export default func;
func.tags = ['HeliosGlobals', 'PoolFactory', 'LiquidityLockerFactory', 'Variables'];
