const { ethers } = require("hardhat")
const { BigNumber } = ethers

// const TRADERJOE_ROUTER = "0x60aE616a2155Ee3d9A68541Ba4544862310933d4"; // Trade Joe Router address in Avalanche
// const UNISWAP_ROUTER = '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff'; // Quisk Swap Router in polygon
// const UNISWAP_FACTORY = '0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32'; // Quisk Swap Factory in Polygon
const UniswapV2Router = require("../abis/UniswapV2Router.json")
const UniswapV2Factory = require("../abis/UniswapV2Factory.json")
const ERC20 = require("../abis/ERC20.json")
const decimals = 18

async function addDreggUSDTLiquidity(router, factory, dreggAddress, usdtAddress, to, signer) {
  const dreggAmount = getBigNumber(10000)
  const usdtAmount = getBigNumber(100, 6)
  const timestamp = new Date().getTime()
  const routerContract = new ethers.Contract(router, JSON.stringify(UniswapV2Router), ethers.provider)
  const factoryContract = new ethers.Contract(factory, JSON.stringify(UniswapV2Factory), ethers.provider)
  const dreggContract = new ethers.Contract(dreggAddress, JSON.stringify(ERC20), ethers.provider)
  const usdtContract = new ethers.Contract(usdtAddress, JSON.stringify(ERC20), ethers.provider)

  console.log("Approving ...")
  await (await dreggContract.connect(signer).approve(router, getBigNumber(10000000), { from: signer.address })).wait()
  await (await usdtContract.connect(signer).approve(router, getBigNumber(10000000), { from: signer.address })).wait()
  console.log("Approved")

  console.log("Adding liquidity...")
  await (
    await routerContract
      .connect(signer)
      .addLiquidity(dreggAddress, usdtAddress, dreggAmount, usdtAmount, dreggAmount, usdtAmount, to, timestamp, {})
  ).wait()

  const pair = await factoryContract.getPair(dreggAddress, usdtAddress)

  return pair
}

function getBigNumber(amount, decimal = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(decimal))
}

module.exports = {
  addDreggUSDTLiquidity,
  getBigNumber,
}
