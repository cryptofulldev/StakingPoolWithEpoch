// const { expect } = require("chai")
// const { ethers, network } = require("hardhat")
// const { getBigNumber, getNumber, getBasicInfo, forkFrom } = require("../scripts/shared/utilities")
// const { BigNumber } = ethers
// const UniswapV2Router = require("../scripts/abis/UniswapV2Router.json")
// const UniswapV2Factory = require("../scripts/abis/UniswapV2Factory.json")
// const ERC20 = require("../scripts/abis/ERC20.json")

// describe("PriceAgent", function () {
//   before(async function () {
//     this.basicInfo = getBasicInfo("rinkeby")
//     this.PriceAgent = await ethers.getContractFactory("PriceAgent")
//     this.MockUSDT = await ethers.getContractFactory("MockUSDT")
//     this.signers = await ethers.getSigners()
//     this.usdcAddress = "0xeb8f08a975ab53e34d8a0330e0d34de942c95926"
//     this.daiAddress = "0x5592ec0cfb4dbc12d3ab100b257153436a1f0fea"
//     // this.usdcAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
//     // this.daiAddress = "0x6b175474e89094c44da98b954eedeac495271d0f"
//     this.routerContract = new ethers.Contract(this.basicInfo.router, JSON.stringify(UniswapV2Router.abi), ethers.provider)
//     this.usdcContract = new ethers.Contract(this.usdcAddress, JSON.stringify(ERC20), ethers.provider)
//     this.daiContract = new ethers.Contract(this.daiAddress, JSON.stringify(ERC20), ethers.provider)  })

//   beforeEach(async function () {
//     // await forkFrom(7041458)

//     this.mockUSDT = await this.MockUSDT.deploy()
//     this.priceAgent = await this.PriceAgent.deploy(
//       this.basicInfo.router,
//       this.mockUSDT.address,
//       ["DAI", "ETH", "USDC"],
//       [this.basicInfo.dai, this.basicInfo.eth, this.basicInfo.usdc],
//     )
//     const timestamp = new Date().getTime()

//     await (
//       await this.mockUSDT
//         .connect(this.signers[0])
//         .approve(this.basicInfo.router, getBigNumber(10000000), { from: this.signers[0].address })
//     ).wait()

//     console.log("Adding liquidity...")

//     await (
//       await this.routerContract
//         .connect(this.signers[0])
//         .addLiquidityETH(
//           this.mockUSDT.address,
//           getBigNumber(3000),
//           getBigNumber(3000),
//           getBigNumber(5),
//           this.signers[0].address,
//           timestamp,
//           { from: this.signers[0].address, value: getBigNumber(5), gasLimit: 9999999 },
//         )
//     ).wait()

//     const weth = await this.routerContract.WETH()
//     const unopath = [weth, this.mockUSDT.address]

//     const getAmountsIn = await this.routerContract.getAmountsIn(getBigNumber(1), unopath)
//     console.log("[getAmountsIn]", getNumber(getAmountsIn[0], 18))

//   })

//   describe("price agent test", function () {
//     it("should get usdc price", async function () {
//       const usdcPrice = await this.priceAgent.getLatestPrice("USDC")
//       console.log("[usdcPrice]", getNumber(usdcPrice, 8))
//     })

//     it("should get dai price", async function () {
//       const daiPrice = await this.priceAgent.getLatestPrice("DAI")
//       console.log("[daiPrice]", getNumber(daiPrice, 8))
//     })

//     it("should get eth price", async function () {
//       const ethPrice = await this.priceAgent.getLatestPrice("ETH")
//       console.log("[ethPrice]", getNumber(ethPrice, 8))
//     })

//     it("should get uno price", async function () {
//       const unoPrice = await this.priceAgent.getLatestPrice("UNO")
//       console.log("[unoPrice]", getNumber(unoPrice, 8))
//     })
//   })
// })
