import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
const { vars } = require("hardhat/config");

const ACCOUNT_PRIVATE_KEY = vars.get("ACCOUNT_PRIVATE_KEY")
const LISK_RPC_URL  = vars.get("LISK_RPC_URL")


const config: HardhatUserConfig = {
    solidity: "0.8.27",
    networks: {
        "lisk-sepolia": {
            url: LISK_RPC_URL!,
            accounts: [ACCOUNT_PRIVATE_KEY!],
            gasPrice: 1000000000,
        }
    },
    etherscan: {
        apiKey: {
            "lisk-sepolia": "123",
        },
        customChains: [
            {
                network: "lisk-sepolia",
                chainId: 4202,
                urls: {
                    apiURL: "https://sepolia-blockscout.lisk.com/api",
                    browserURL: "https://sepolia-blockscout.lisk.com/",
                },
            },
        ],
    },
    sourcify: {
        enabled: false,
    },
};

export default config;