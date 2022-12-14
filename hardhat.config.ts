// noinspection JSUnusedGlobalSymbols
import "dotenv/config";
import {HardhatUserConfig} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-abi-exporter";
import "hardhat-storage-layout";
import "hardhat-contract-sizer";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.8",
        settings: {
            optimizer: {
                enabled: true,
                runs: 300,
            },
            outputSelection: {
                "*": {
                    "*": ["storageLayout"],
                },
            }
        },
    },
    gasReporter: {
        enabled: true,
        currency: "USD",
        url: "http://localhost:8545",
        coinmarketcap: process.env.COIN_MARKET_CAP
    },
    abiExporter: {
        path: './abi',
        only: [
            'Pool',
            'PoolFactory',
            'HeliosGlobals',
            'LiquidityLocker',
            'LiquidityLockerFactory'
        ],
        runOnCompile: true,
        flat: true,
        spacing: 2,
        pretty: false,
    },

    networks: {
        hardhat: {
            chainId: 31337,
            forking:{
                url: process.env.MAIN_NET_FORK_API_KEY!,
            }
        },
        goerli: {
            url: process.env.GOERLI_API_KEY,
            accounts: [
                process.env.GOERLI_OWNER_PRIVATE_KEY!,
                process.env.GOERLI_ADMIN_PRIVATE_KEY!,
                process.env.GOERLI_USER_PRIVATE_KEY!
            ]
        }
    }
};

export default config;
