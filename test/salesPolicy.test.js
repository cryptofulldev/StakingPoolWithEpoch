// const { expect } = require("chai")
// const { ethers, network } = require("hardhat")
// const { getBigNumber, getNumber, getBasicInfo } = require("../scripts/shared/utilities")
// const { BigNumber } = ethers
// const UniswapV2Router = require("../scripts/abis/UniswapV2Router.json")
// const ERC20 = require("../scripts/abis/ERC20.json")

// describe("SalesPolicy", function () {
//   before(async function () {
//     this.basicInfo = getBasicInfo("rinkeby")
//     this.usdcAddress = "0xeb8f08a975ab53e34d8a0330e0d34de942c95926"
//     this.daiAddress = "0x5592ec0cfb4dbc12d3ab100b257153436a1f0fea"
//     this.Actuary = await ethers.getContractFactory("Actuary")
//     this.ClaimAssessor = await ethers.getContractFactory("ClaimAssessor")
//     this.CohortFactory = await ethers.getContractFactory("CohortFactory")
//     this.Cohort = await ethers.getContractFactory("Cohort")
//     this.PriceAgent = await ethers.getContractFactory("PriceAgent")
//     this.PremiumPoolFactory = await ethers.getContractFactory("PremiumPoolFactory")
//     this.PremiumPool = await ethers.getContractFactory("PremiumPool")
//     this.RiskPoolFactory = await ethers.getContractFactory("RiskPoolFactory")
//     this.RiskPool = await ethers.getContractFactory("RiskPool")
//     this.MockUNO = await ethers.getContractFactory("MockUNO")
//     this.SalesPolicy = await ethers.getContractFactory("SalesPolicy")
//     this.signers = await ethers.getSigners()
//     this.routerContract = new ethers.Contract(this.basicInfo.router, JSON.stringify(UniswapV2Router.abi), ethers.provider)
//     this.usdcContract = new ethers.Contract(this.usdcAddress, JSON.stringify(ERC20), ethers.provider)
//     this.daiContract = new ethers.Contract(this.daiAddress, JSON.stringify(ERC20), ethers.provider)
//   })

//   beforeEach(async function () {
//     this.mockUNO = await this.MockUNO.deploy()
//     this.claimAssessor = await this.ClaimAssessor.deploy()
//     this.actuary = await this.Actuary.deploy(this.claimAssessor.address)
//     this.cohortFactory = await this.CohortFactory.deploy(this.actuary.address)
//     this.premiumPoolFactory = await this.PremiumPoolFactory.deploy()
//     this.riskPoolFactory = await this.RiskPoolFactory.deploy()
//     this.priceAgent = await this.PriceAgent.deploy(
//       this.basicInfo.router,
//       this.mockUNO.address,
//       ["DAI", "ETH", "USDC"],
//       [this.basicInfo.dai, this.basicInfo.eth, this.basicInfo.usdc],
//     )

//     this.actuaryOwner = this.signers[0].address

//     const createCohortTx = await this.actuary.createCohort(
//       this.cohortFactory.address,
//       this.priceAgent.address,
//       "My Cohort",
//       getBigNumber(1000000),
//       this.premiumPoolFactory.address,
//       getBigNumber(1000),
//     )
//     this.cohortAddress = (await createCohortTx.wait()).events[0].args.cohort
//     this.cohort = await this.Cohort.attach(this.cohortAddress)
//     this.premiumPoolAddress = await this.cohort.premiumPool()
//     this.premiumPool = await this.PremiumPool.attach(this.premiumPoolAddress)

//     this.mockUNO.transfer(this.signers[1].address, getBigNumber(2000000))
//     this.mockUNO.transfer(this.signers[2].address, getBigNumber(3000000))

//     this.salesPolicy = await this.SalesPolicy.deploy(this.cohortAddress)

//     // add 2 protocols
//     for (let idx = 0; idx < 2; idx++) {
//       await this.cohort.addProtocol(
//         `Protocol${idx + 1}`,
//         this.signers[idx + 1].address,
//         this.usdcAddress,
//         `Product${idx + 1}`,
//         `PremiumDescription${idx + 1}`,
//         idx * 200 + 400,
//         400,
//         BigNumber.from(24 * 3600 * 365),
//       )
//     }

//     expect(await this.cohort.allProtocolsLength()).equal(2)

//     // deposit 300000 into premium
//     await this.mockUNO.approve(this.cohort.address, getBigNumber(1000000))
//     await (
//       await this.usdcContract
//         .connect(this.signers[0])
//         .approve(this.cohort.address, getBigNumber(10000000, 6), { from: this.signers[0].address })
//     ).wait()

//     await this.cohort.depositPremium(0, getBigNumber(100000))
//     await this.cohort.depositPremium(1, getBigNumber(200000))

//     // 2 risk pool create
//     await this.cohort.createRiskPool("RP1", "xRP1", this.riskPoolFactory.address, this.mockUNO.address, getBigNumber(1000000))

//     await this.cohort.createRiskPool("RP2", "xRP2", this.riskPoolFactory.address, this.mockUNO.address, getBigNumber(1000000))

//     this.poolAddress1 = await this.cohort.getRiskPool(0)
//     this.poolAddress2 = await this.cohort.getRiskPool(1)

//     await this.mockUNO.approve(this.premiumPool.address, getBigNumber(10000000))
//     await this.mockUNO
//       .connect(this.signers[1])
//       .approve(this.premiumPool.address, getBigNumber(10000000), { from: this.signers[1].address })

//     await this.mockUNO.approve(this.cohort.address, getBigNumber(10000000))
//     await this.mockUNO
//       .connect(this.signers[1])
//       .approve(this.cohort.address, getBigNumber(10000000), { from: this.signers[1].address })

//     await this.cohort.initialRiskPool(this.poolAddress1, getBigNumber(500000), 400, [600, 400])
//     await this.cohort.initialRiskPool(this.poolAddress2, getBigNumber(500000), 600, [400, 600])

//     const cohortActiveFrom = await this.cohort.cohortActiveFrom()
//     expect(cohortActiveFrom).not.equal(0)
//   })

//   describe("Sales policy register", function () {
//     it("Should register sales policy to the protocol", async function () {
//       await this.salesPolicy.registerPolicy("Policy I", this.signers[2].address, 0, getBigNumber(1000))

//       const policiesLength = await this.salesPolicy.allPoliciesLength()
//       expect(policiesLength).to.equal(1)
//     })
//     it("Should buy policy", async function () {
//       // register 2 policy
//       await this.salesPolicy.registerPolicy("Policy I", this.signers[1].address, 0, getBigNumber(1000))

//       await this.salesPolicy.registerPolicy("Policy II", this.signers[2].address, 1, getBigNumber(500))

//       const policiesLength = await this.salesPolicy.allPoliciesLength()
//       expect(policiesLength).to.equal(2)

//       const signer1BalanceBefore = await this.mockUNO.balanceOf(this.signers[1].address)
//       const signer2BalanceBefore = await this.mockUNO.balanceOf(this.signers[2].address)

//       // the first policy's owner is signer 1 before sales
//       const policyOwnerBefore = await this.salesPolicy.getPolicy(0)
//       expect(policyOwnerBefore[1]).to.equal(this.signers[1].address)

//       // should approve buyer's token to sales policy contract before buy policy
//       await this.mockUNO
//         .connect(this.signers[2])
//         .approve(this.salesPolicy.address, getBigNumber(10000000), { from: this.signers[2].address })

//       // singer 2 buy policy from signer 1.
//       await this.salesPolicy.connect(this.signers[2]).buyPolicy(0, { from: this.signers[2].address })

//       const signer1BalanceAfter = await this.mockUNO.balanceOf(this.signers[1].address)
//       const signer2BalanceAfter = await this.mockUNO.balanceOf(this.signers[2].address)

//       const policyAfter = await this.salesPolicy.getPolicy(0)

//       expect(signer1BalanceAfter).to.equal(signer1BalanceBefore.add(policyAfter[4]))
//       expect(signer2BalanceAfter).to.equal(signer2BalanceBefore.sub(policyAfter[4]))

//       // policy's owner will be transfered to singer 2 after sales.
//       const policyOwnerAfter = policyAfter[1]
//       expect(policyOwnerAfter).to.equal(this.signers[2].address)
//     })
//   })
// })
