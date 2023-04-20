// noinspection JSUnusedGlobalSymbols
import "dotenv/config";
import {HardhatUserConfig} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-abi-exporter";
import "hardhat-storage-layout";
import "hardhat-contract-sizer";
import "@nomiclabs/hardhat-etherscan";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.16",
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
            'LiquidityLockerFactory',
            'IERC20Metadata',
            'IERC20',
        ],
        runOnCompile: true,
        flat: true,
        spacing: 2,
        pretty: false,
    },

    networks: {
        hardhat: {
            chainId: 31337,
            forking: {
                enabled: true,
                url: process.env.MAIN_NET_FORK_API_KEY!,
            }
        },
        alfajores: {
            url: process.env.CELO_API_KEY,
            accounts: [
                process.env.CELO_OWNER_PRIVATE_KEY!,
                process.env.CELO_ADMIN_PRIVATE_KEY!,
                process.env.CELO_USER_PRIVATE_KEY!,
                process.env.CELO_BORROWER_PRIVATE_KEY!,
            ],
            chainId: 44787,
        },
        goerli: {
            url: process.env.GOERLI_API_KEY,
            accounts: [
                process.env.GOERLI_OWNER_PRIVATE_KEY!,
                process.env.GOERLI_ADMIN_PRIVATE_KEY!,
                process.env.GOERLI_USER_PRIVATE_KEY!,
                process.env.GOERLI_BORROWER_PRIVATE_KEY!
            ]
        },
    },
    etherscan: {
        apiKey: {
            goerli: process.env.ETHERSCAN_API_KEY!
        },
        customChains: [
            {
                network: "goerli",
                chainId: 5,
                urls: {
                    apiURL: "https://api-goerli.etherscan.io/api",
                    browserURL: "https://goerli.etherscan.io"
                }
            }
        ]
    }
}

    export default config;
