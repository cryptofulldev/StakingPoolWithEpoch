const { ethers, network } = require("hardhat")
const hre = require("hardhat")
const { BigNumber } = ethers

function getCreate2CohortAddress(actuaryAddress, { cohortName, sender, nonce }, bytecode) {
  const create2Inputs = [
    "0xff",
    actuaryAddress,
    ethers.utils.keccak256(ethers.utils.solidityPack(["address", "string", "uint"], [sender, cohortName, nonce])),
    ethers.utils.keccak256(bytecode),
  ]
  const sanitizedInputs = `0x${create2Inputs.map((i) => i.slice(2)).join("")}`

  return ethers.utils.getAddress(`0x${ethers.utils.keccak256(sanitizedInputs).slice(-40)}`)
}

// Defaults to e18 using amount * 10^18
function getBigNumber(amount, decimals = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(decimals))
}

// Defaults to e18 using amount * 10^18
function getNumber(amount, decimals = 18) {
  return BigNumber.from(amount).div(BigNumber.from(10).pow(decimals)).toNumber()
}

const basicInfo = {
  ethereum: {
    router: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    factory: "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",
    uno: "0x474021845c4643113458ea4414bdb7fb74a01a77",
    dai: "0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9",
    eth: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
    usdt: "0x3E7d1eAB13ad0104d2750B8863b489D65364e32D",
    usdc: "0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6",
  },
  rinkeby: {
    router: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    factory: "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",
    uno: "",
    dai: "0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF",
    eth: "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e",
    usdt: "",
    usdc: "0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB",
  },
  bscMain: {
    router: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
    factory: "",
    uno: "0x474021845c4643113458ea4414bdb7fb74a01a77",
    dai: "0x132d3C0B1D2cEa0BC552588063bdBb210FDeecfA",
    eth: "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e",
    usdt: "0xB97Ad0E74fa7d920791E90258A6E2085088b4320",
    usdc: "0x51597f405303C4377E36123cBc172b13269EA163",
  },
  bscTest: {
    router: "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
    factory: "",
    uno: "",
    dai: "0xE4eE17114774713d2De0eC0f035d4F7665fc025D",
    eth: "0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7",
    usdt: "0xEca2605f0BCF2BA5966372C99837b1F182d3D620",
    usdc: "0x90c069C4538adAc136E051052E14c1cD799C41B7",
  },
}

function getBasicInfo(network) {
  return basicInfo[network]
}

async function forkFrom(blockNumber) {
  if (!hre.config.networks.hardhat.forking) {
    throw new Error(`Forking misconfigured for "hardhat" network in hardhat.config.ts`)
  }

  console.log("[hardhat_reset]", hre.config.networks.hardhat.forking.blockNumber, blockNumber)

  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: hre.config.networks.hardhat.forking.url,
          blockNumber: blockNumber,
        },
      },
    ],
  })
}

module.exports = {
  getCreate2CohortAddress,
  getBigNumber,
  getNumber,
  getBasicInfo,
  forkFrom,
}
