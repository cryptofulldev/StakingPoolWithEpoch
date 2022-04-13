// const { expect } = require("chai")
// const { ethers } = require("hardhat")
// const UniswapV2Router = require("../scripts/abis/UniswapV2Router.json")
// const UniswapV2Factory = require("../scripts/abis/UniswapV2Factory.json")
// const ERC20 = require("../scripts/abis/ERC20.json")

// const { getBigNumber, getBasicInfo } = require("../scripts/shared/utilities")

// describe("Actuary", async function () {
//   before(async function () {
//     this.basicInfo = getBasicInfo("rinkeby")
//     this.usdcAddress = "0xeb8f08a975ab53e34d8a0330e0d34de942c95926"
//     this.daiAddress = "0x5592ec0cfb4dbc12d3ab100b257153436a1f0fea"
//     // this.usdcAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
//     // this.daiAddress = "0x6b175474e89094c44da98b954eedeac495271d0f"
//     this.Actuary = await ethers.getContractFactory("Actuary")
//     this.CohortFactory = await ethers.getContractFactory("CohortFactory")
//     this.Cohort = await ethers.getContractFactory("Cohort")
//     this.PriceAgent = await ethers.getContractFactory("PriceAgent")
//     this.PremiumPoolFactory = await ethers.getContractFactory("PremiumPoolFactory")
//     this.ClaimAssessor = await ethers.getContractFactory("ClaimAssessor")
//     this.MockUNO = await ethers.getContractFactory("MockUNO")
//     this.signers = await ethers.getSigners()
//     this.routerContract = new ethers.Contract(this.basicInfo.router, JSON.stringify(UniswapV2Router.abi), ethers.provider)
//     // this.factoryContract = new ethers.Contract(this.basicInfo.factory, JSON.stringify(UniswapV2Factory.abi), ethers.provider);
//     this.usdcContract = new ethers.Contract(this.usdcAddress, JSON.stringify(ERC20), ethers.provider)
//     this.daiContract = new ethers.Contract(this.daiAddress, JSON.stringify(ERC20), ethers.provider)

//     console.log("Approving ...", this.signers[0].address)
//     await (
//       await this.usdcContract.connect(this.signers[0]).approve(this.basicInfo.router, getBigNumber(10000000), {
//         from: this.signers[0].address,
//       })
//     ).wait()
//     await (
//       await this.daiContract.connect(this.signers[0]).approve(this.basicInfo.router, getBigNumber(10000000), {
//         from: this.signers[0].address,
//       })
//     ).wait()
//     console.log("Approved...")
//   })

//   beforeEach(async function () {
//     this.mockUNO = await this.MockUNO.deploy()
//     this.claimAssessor = await this.ClaimAssessor.deploy()
//     this.actuary = await this.Actuary.deploy(this.claimAssessor.address)
//     this.cohortFactory = await this.CohortFactory.deploy(this.actuary.address)
//     this.premiumPoolFactory = await this.PremiumPoolFactory.deploy()
//     this.priceAgent = await this.PriceAgent.deploy(
//       this.basicInfo.router,
//       this.mockUNO.address,
//       ["DAI", "ETH", "USDC"],
//       [this.basicInfo.dai, this.basicInfo.eth, this.basicInfo.usdc],
//     )

//     this.actuaryOwner = this.signers[0].address
//   })

//   it("Should create Cohort by Cohort creator", async function () {
//     const createCohortTx = await this.actuary.createCohort(
//       this.cohortFactory.address,
//       this.priceAgent.address,
//       "My Cohort",
//       getBigNumber(1000000),
//       this.premiumPoolFactory.address,
//       getBigNumber(1000),
//     )
//     const cohortAddr = (await createCohortTx.wait()).events[0].args.cohort

//     const cohort = await this.Cohort.attach(cohortAddr)
//     const cohortOwner = await cohort.owner()
//     expect(cohortOwner).to.equal(this.signers[0].address)
//   })

//   it("Should not allow other users to create cohort except cohort creator", async function () {
//     await expect(
//       this.actuary
//         .connect(this.signers[1])
//         .createCohort(
//           this.cohortFactory.address,
//           this.priceAgent.address,
//           "My Cohort",
//           getBigNumber(1000000),
//           this.premiumPoolFactory.address,
//           getBigNumber(1000),
//           { from: this.signers[1].address },
//         ),
//     ).to.be.revertedWith("UnoRe: Forbidden")
//   })

//   it("Should add one cohort creator", async function () {
//     await this.actuary.addCohortCreator(this.signers[1].address)
//     await expect(this.actuary.isCohortCreator(this.signers[1].address), true)
//   })

//   it("Should withdraw cohort creation fee from Actuary", async function () {
//     await this.actuary.setCohortCreationFee(getBigNumber(1))
//     await expect(this.actuary.cohortCreateFee(), getBigNumber(1))

//     await this.actuary.addCohortCreator(this.signers[1].address)
//     await this.actuary
//       .connect(this.signers[1])
//       .createCohort(
//         this.cohortFactory.address,
//         this.priceAgent.address,
//         "My Cohort",
//         getBigNumber(1000000),
//         this.premiumPoolFactory.address,
//         getBigNumber(1000),
//         { from: this.signers[1].address, value: getBigNumber(1) },
//       )

//     const balanceBefore = await ethers.provider.getBalance(this.signers[0].address)
//     await expect(ethers.provider.getBalance(this.actuary.address), getBigNumber(1))
//     await this.actuary.withdrawCreateFee(this.signers[0].address)
//     const balanceAfter = await ethers.provider.getBalance(this.signers[0].address)

//     expect(balanceBefore.add(getBigNumber(1)), balanceAfter)
//   })
// })
