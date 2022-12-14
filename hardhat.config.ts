import "hardhat-gas-reporter"
import "solidity-coverage";
import "@nomicfoundation/hardhat-toolbox"
import { config as dotenvConfig } from "dotenv"
import { HardhatUserConfig } from "hardhat/config"
import { NetworksUserConfig } from "hardhat/types"
import { resolve } from "path"
import { config } from "./package.json"

dotenvConfig({ path: resolve(__dirname, "./.env") })

function getNetworks(): NetworksUserConfig {
  if (!process.env.INFURA_API_KEY)
    throw new Error(
      `INFURA_API_KEY env var not set. Copy .env.template to .env and set the env var`
    )
  if (!process.env.MNEMONIC)
    throw new Error(`MNEMONIC env var not set. Copy .env.template to .env and set the env var`)

  const infuraApiKey = process.env.INFURA_API_KEY;
  const alchemyApiKey = process.env.ALCHEMY_API_KEY;

  return {
    hardhat: {
      forking: {
        url: `https://mainnet.infura.io/v3/${infuraApiKey}`,
        //blockNumber:,
        enabled: true,
      },
    },
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${alchemyApiKey}`,
      chainId: 1,
      accounts: [`0x${process.env.PROJECT_PK}`],
    },
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/${alchemyApiKey}`,
      chainId: 5,
      accounts: [`0x${process.env.PROJECT_PK_TEST}`],
    }
  }
}

const hardhatConfig: HardhatUserConfig = {
  solidity: config.solidity,
  paths: {
    sources: config.paths.contracts,
    tests: config.paths.tests,
    cache: config.paths.cache,
    artifacts: config.paths.build.contracts,
  },
  networks: {
    ...getNetworks(),
  },
  typechain: {
    outDir: config.paths.build.typechain,
    target: "ethers-v5",
  },
  etherscan: {
    apiKey: {
      mainnet: `${process.env.ETHERSCAN_API_KEY}`,
      goerli: `${process.env.ETHERSCAN_API_KEY}`
    },
  },
  mocha: {
    timeout: 1200 * 1e3,
  },
  gasReporter: {
    enabled: (process.env.REPORT_GAS) ? true : false
  }
}

export default hardhatConfig