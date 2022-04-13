const { expect } = require("chai")
const { ethers, network } = require("hardhat")
const { getBigNumber, getNumber, getBasicInfo } = require("../scripts/shared/utilities")
const { BigNumber } = ethers
const UniswapV2Router = require("../scripts/abis/UniswapV2Router.json")
const UniswapV2Factory = require("../scripts/abis/UniswapV2Factory.json")
const ERC20 = require("../scripts/abis/ERC20.json")
const SalesPolicy = require("../scripts/abis/SalesPolicy.json")

describe("Cohort", function () {
  before(async function () {
    this.basicInfo = getBasicInfo("rinkeby")
    this.usdcAddress = "0xeb8f08a975ab53e34d8a0330e0d34de942c95926"
    this.daiAddress = "0x5592ec0cfb4dbc12d3ab100b257153436a1f0fea"
    // this.usdcAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" // ethereum
    // this.daiAddress = "0x6b175474e89094c44da98b954eedeac495271d0f"  // ethereum
    this.Actuary = await ethers.getContractFactory("Actuary")
    this.ClaimAssessor = await ethers.getContractFactory("ClaimAssessor")
    this.CohortFactory = await ethers.getContractFactory("CohortFactory")
    this.Cohort = await ethers.getContractFactory("Cohort")
    this.PriceAgent = await ethers.getContractFactory("PriceAgent")
    this.PremiumPoolFactory = await ethers.getContractFactory("PremiumPoolFactory")
    this.PremiumPool = await ethers.getContractFactory("PremiumPool")
    this.RiskPoolFactory = await ethers.getContractFactory("RiskPoolFactory")
    this.RiskPool = await ethers.getContractFactory("RiskPool")
    this.MockUNO = await ethers.getContractFactory("MockUNO")
    this.SalesPolicyFactory = await ethers.getContractFactory("SalesPolicyFactory")
    this.signers = await ethers.getSigners()
    this.zeroAddress = ethers.constants.AddressZero
    this.routerContract = new ethers.Contract(this.basicInfo.router, JSON.stringify(UniswapV2Router.abi), ethers.provider)
    this.usdcContract = new ethers.Contract(this.usdcAddress, JSON.stringify(ERC20), ethers.provider)
    this.daiContract = new ethers.Contract(this.daiAddress, JSON.stringify(ERC20), ethers.provider)

    this.mockUNO = await this.MockUNO.deploy()

    const daiBalane = await this.daiContract.balanceOf(this.signers[0].address)
    console.log("[daiBalane]", getNumber(daiBalane, 6))

    const usdcBalance1 = await this.usdcContract.balanceOf(this.signers[0].address)
    console.log("[usdcBalance]", getNumber(usdcBalance1, 6))

    const ethBalane = await ethers.provider.getBalance(this.signers[0].address)
    console.log("[ethBalane]", getNumber(ethBalane))

    // It is action to get mockUNO's price
    const timestamp = new Date().getTime()

    await (
      await this.mockUNO
        .connect(this.signers[0])
        .approve(this.basicInfo.router, getBigNumber(10000000), { from: this.signers[0].address })
    ).wait()

    console.log("Adding liquidity...")

    await (
      await this.routerContract
        .connect(this.signers[0])
        .addLiquidityETH(
          this.mockUNO.address,
          getBigNumber(3000),
          getBigNumber(3000),
          getBigNumber(5),
          this.signers[0].address,
          timestamp,
          { from: this.signers[0].address, value: getBigNumber(5), gasLimit: 9999999 },
        )
    ).wait()

    const usdcBalance = await this.usdcContract.balanceOf(this.signers[0].address)
    expect(getNumber(usdcBalance, 6), 2000000000000)
  })

  beforeEach(async function () {
    this.claimAssessor = await this.ClaimAssessor.deploy()
    this.actuary = await this.Actuary.deploy(this.claimAssessor.address)
    this.actuaryOwner = this.signers[0].address
    this.cohortFactory = await this.CohortFactory.deploy(this.actuary.address)
    this.premiumPoolFactory = await this.PremiumPoolFactory.deploy()
    this.riskPoolFactory = await this.RiskPoolFactory.deploy()
    this.priceAgent = await this.PriceAgent.deploy(
      this.basicInfo.router,
      this.mockUNO.address,
      ["DAI", "ETH", "USDC"],
      [this.basicInfo.dai, this.basicInfo.eth, this.basicInfo.usdc],
    )
    this.salesPolicyFactory = await this.SalesPolicyFactory.deploy()

    const createCohortTx = await this.actuary.createCohort(
      this.cohortFactory.address, // cohort factory address
      this.priceAgent.address, // price agent contract address
      "My Cohort", // cohort name
      getBigNumber(1000000), // cohortStartCapital
      this.premiumPoolFactory.address, // premiumfactory
      getBigNumber(1000, 6), // minPremium
    )
    this.cohortAddress = (await createCohortTx.wait()).events[0].args.cohort
    this.cohort = await this.Cohort.attach(this.cohortAddress)
    this.premiumPoolAddress = await this.cohort.premiumPool()
    this.premiumPool = await this.PremiumPool.attach(this.premiumPoolAddress)

    await this.cohort.setMCR(220)

    this.mockUNO.transfer(this.signers[1].address, getBigNumber(2000000))
    this.mockUNO.transfer(this.signers[2].address, getBigNumber(1000000))
  })

  // describe("Cohort Basic", function () {
  //   it("Should not allow others to add protocol", async function () {
  //     await expect(
  //       this.cohort
  //         .connect(this.signers[1])
  //         .addProtocol(
  //           "Protocol1",
  //           this.signers[2].address,
  //           this.usdcAddress,
  //           "Product1",
  //           "PremiumDescription1",
  //           600, // mcr
  //           400, // premium factor
  //           BigNumber.from(24 * 3600).mul(365),
  //           this.salesPolicyFactory.address,
  //           { from: this.signers[1].address },
  //         ),
  //     ).to.be.revertedWith("UnoRe: Forbidden")
  //   })

  //   it("Should add protocol", async function () {
  //     await this.cohort.addProtocol(
  //       "Protocol1",
  //       this.signers[1].address,
  //       this.usdcAddress,
  //       "Product1",
  //       "PremiumDescription1",
  //       600,
  //       400,
  //       BigNumber.from(24 * 3600).mul(BigNumber.from(365)),
  //       this.salesPolicyFactory.address,
  //     )
  //     expect(await this.cohort.allProtocolsLength()).equal(1)
  //   })

  //   it("Should deposit premium at cohort", async function () {
  //     await this.cohort.addProtocol(
  //       "Protocol1", // protocol name
  //       this.signers[1].address, // protocol address
  //       this.usdcAddress, // protocol currency
  //       "Product1", // product type
  //       "PremiumDescription1", // premium description
  //       400, // protocol MCR
  //       300, // premium factor
  //       BigNumber.from(24 * 3600).mul(BigNumber.from(365)), //cover duration
  //       this.salesPolicyFactory.address,
  //     )

  //     await this.cohort.addProtocol(
  //       "Protocol2", // protocol name
  //       this.signers[2].address, // protocol address
  //       this.daiAddress, // protocol currency
  //       "Product2", // product type
  //       "PremiumDescription2", // premium description
  //       300, // protocol MCR
  //       500, // premium factor
  //       BigNumber.from(24 * 3600).mul(BigNumber.from(365)), //cover duration
  //       this.salesPolicyFactory.address,
  //     )

  //     // approve cohort for the signer 0's mockUNO
  //     await this.mockUNO.approve(this.cohort.address, getBigNumber(1000000))
  //     // approve cohort for the signer 0's usdc
  //     await (
  //       await this.usdcContract
  //         .connect(this.signers[0])
  //         .approve(this.cohort.address, getBigNumber(10000000, 6), { from: this.signers[0].address })
  //     ).wait()
  //     // approve cohort for the signer 0's dai
  //     await (
  //       await this.daiContract
  //         .connect(this.signers[0])
  //         .approve(this.cohort.address, getBigNumber(10000000, 6), { from: this.signers[0].address })
  //     ).wait()

  //     // deposit 1000 USDC into protocol 0
  //     await this.cohort.depositPremium(0, getBigNumber(1000, 6))
  //     const premiumDepositedUSDC = await this.premiumPool.balanceOf(0)

  //     expect(premiumDepositedUSDC).to.equal(getBigNumber(1000, 6))

  //     // deposit 1000 DAI into protocol 1
  //     await this.cohort.depositPremium(1, getBigNumber(1000, 6))
  //     const premiumDepositedDAI = await this.premiumPool.balanceOf(1)

  //     expect(premiumDepositedDAI).to.equal(getBigNumber(1000, 6))

  //     expect(await this.cohort.allProtocolsLength()).equal(2)
  //   })

  //   it("Should not allow others to create risk pool", async function () {
  //     await expect(
  //       this.cohort
  //         .connect(this.signers[1])
  //         .createRiskPool("RP", "xRP", this.riskPoolFactory.address, this.mockUNO.address, getBigNumber(1000000), {
  //           from: this.signers[1].address,
  //         }),
  //     ).to.be.revertedWith("UnoRe: Forbidden")
  //   })

  //   it("Should create Risk Pool", async function () {
  //     await this.cohort.createRiskPool("RP", "xRP", this.riskPoolFactory.address, this.mockUNO.address, getBigNumber(1000000))
  //     expect(await this.cohort.allRiskPoolLength()).equal(1)
  //   })
  // })

  describe("Cohort Actions", function () {
    beforeEach(async function () {
      // We create 2 protocols and 2 Risk Pools
      for (let idx = 0; idx < 2; idx++) {
        await this.cohort.addProtocol(
          `Protocol${idx + 1}`,
          this.signers[idx + 1].address,
          this.usdcAddress,
          `Product${idx + 1}`,
          `PremiumDescription${idx + 1}`,
          idx * 200 + 400,
          40,
          BigNumber.from(24 * 3600 * 365),
          this.salesPolicyFactory.address,
        )
      }

      await this.cohort.setProtocolMCR(0, 500)

      const protocol1 = await this.cohort.getProtocol(0)
      this.salesPolicyAddress1 = protocol1.salesPolicy

      // 60% APR
      await this.cohort.createRiskPool("RP1", "xRP1", this.riskPoolFactory.address, this.mockUNO.address, getBigNumber(1000000))
      // 40% APR
      await this.cohort.createRiskPool("RP2", "xRP2", this.riskPoolFactory.address, this.mockUNO.address, getBigNumber(1000000))

      this.poolAddress1 = await this.cohort.getRiskPool(0)
      this.poolAddress2 = await this.cohort.getRiskPool(1)

      await this.mockUNO.approve(this.premiumPool.address, getBigNumber(10000000))
      await this.mockUNO
        .connect(this.signers[1])
        .approve(this.premiumPool.address, getBigNumber(10000000), { from: this.signers[1].address })

      await this.mockUNO.approve(this.cohort.address, getBigNumber(10000000))
      await this.mockUNO
        .connect(this.signers[1])
        .approve(this.cohort.address, getBigNumber(10000000), { from: this.signers[1].address })

      await (
        await this.usdcContract
          .connect(this.signers[0])
          .approve(this.cohort.address, getBigNumber(10000000, 6), { from: this.signers[0].address })
      ).wait()

      // deposited 3000 USDC as premium
      await this.cohort.depositPremium(0, getBigNumber(100000, 6))
      await this.cohort.depositPremium(1, getBigNumber(100000, 6))

      expect((await this.cohort.allProtocolsLength()).toString()).not.equal(2)

      await this.cohort.initialRiskPool(this.poolAddress1, getBigNumber(500000), 400, [400, 600])
      await this.cohort.initialRiskPool(this.poolAddress2, getBigNumber(500000), 600, [600, 400])

      const cohortActiveFrom = await this.cohort.cohortActiveFrom()
      expect(cohortActiveFrom).not.equal(0)
    })

    // describe("Cohort Staking", function () {
    //   it("Should enter in pool but it is in pending yet", async function () {
    //     const riskPool = this.RiskPool.attach(this.poolAddress1)
    //     await this.cohort.enterInPool(this.signers[0].address, this.poolAddress1, getBigNumber(100000))
    //     const poolBalance = await riskPool.balanceOf(this.signers[0].address)
    //     expect(getNumber(poolBalance)).to.equal(500000)
    //     const pendingAmount = await riskPool._depositQueue(this.signers[0].address)
    //     expect(getNumber(pendingAmount[0])).to.equal(100000)
    //   })
    //   it("Should enter in pool and old pending investment is deposited really", async function () {
    //     const riskPool = this.RiskPool.attach(this.poolAddress1)

    //     // investor put money in the risk pool but it will be in pending now.
    //     await this.cohort.enterInPool(this.signers[0].address, this.poolAddress1, getBigNumber(100000))
    //     let poolBalance = await riskPool.balanceOf(this.signers[0].address)
    //     expect(poolBalance).to.equal(getBigNumber(500000))

    //     let poolSize = await riskPool.totalSupply()
    //     expect(poolSize).to.equal(getBigNumber(500000))

    //     const currentDate = new Date()
    //     const afterFiveDays = new Date(currentDate.setDate(currentDate.getDate() + 5))
    //     const afterFiveDaysTimeStampUTC = new Date(afterFiveDays.toUTCString()).getTime() / 1000
    //     network.provider.send("evm_setNextBlockTimestamp", [afterFiveDaysTimeStampUTC]) // 2021-8-31-4:1:21 pm
    //     await network.provider.send("evm_mine")

    //     // investor deposites money again in the next epoch
    //     await this.cohort.enterInPool(this.signers[0].address, this.poolAddress1, getBigNumber(100000))
    //     await this.cohort
    //       .connect(this.signers[1])
    //       .enterInPool(this.signers[1].address, this.poolAddress1, getBigNumber(100000), { from: this.signers[1].address })
    //     // there will be only new 100000 in the pending request.
    //     let depositStatus1 = await riskPool._depositQueue(this.signers[0].address)
    //     expect(depositStatus1[0]).to.equal(getBigNumber(100000))
    //     let depositStatus2 = await riskPool._depositQueue(this.signers[1].address)
    //     expect(depositStatus2[0]).to.equal(getBigNumber(100000))
    //     // the first investment will be charged into the risk pool really and
    //     // investor's balance will increase 500000->600000
    //     poolBalance = await riskPool.balanceOf(this.signers[0].address)
    //     expect(poolBalance).to.equal(getBigNumber(600000))
    //     poolBalance = await riskPool.balanceOf(this.signers[1].address)
    //     expect(poolBalance).to.equal(getBigNumber(0))
    //     poolSize = await riskPool.totalSupply()
    //     expect(poolSize).to.equal(getBigNumber(600000))

    //     const afterFiveDaysSecond = new Date(afterFiveDays.setDate(afterFiveDays.getDate() + 5))
    //     const afterFiveDaysTimeStampUTCSecond = new Date(afterFiveDaysSecond.toUTCString()).getTime() / 1000
    //     network.provider.send("evm_setNextBlockTimestamp", [afterFiveDaysTimeStampUTCSecond]) // 2021-8-31-4:1:21 pm
    //     await network.provider.send("evm_mine")

    //     // At the third epoch time, the seconds investments was not charged yet but invetor's balance will seem to be increased.
    //     poolBalance = await riskPool.balanceOf(this.signers[0].address)
    //     expect(poolBalance).to.equal(getBigNumber(700000))

    //     // At the third epoch time, implement deposit requests.
    //     await this.cohort.batchImplementForDepositRequest(this.poolAddress1)

    //     // All deposit requests will be initialized with zero.
    //     depositStatus1 = await riskPool._depositQueue(this.signers[0].address)
    //     expect(depositStatus1[0]).to.equal(getBigNumber(0))
    //     depositStatus2 = await riskPool._depositQueue(this.signers[1].address)
    //     expect(depositStatus2[0]).to.equal(getBigNumber(0))
    //     poolBalance = await riskPool.balanceOf(this.signers[0].address)
    //     expect(poolBalance).to.equal(getBigNumber(700000))
    //     poolBalance = await riskPool.balanceOf(this.signers[1].address)
    //     expect(poolBalance).to.equal(getBigNumber(100000))
    //     poolSize = await riskPool.totalSupply()
    //     expect(poolSize).to.equal(getBigNumber(800000))
    //   })
    // })

    describe("Cohort Claim Request & Withdraw", function () {
      beforeEach(async function () {
        // We staked 100,000 USDT in Risk Pool 1 and in Risk Pool2
        await this.cohort.enterInPool(this.signers[0].address, this.poolAddress1, getBigNumber(100000))

        await this.cohort
          .connect(this.signers[1])
          .enterInPool(this.signers[1].address, this.poolAddress2, getBigNumber(100000), { from: this.signers[1].address })
      })

      // it("Should stop withdraw request in rebalance period", async function() {
      //   const riskPool = this.RiskPool.attach(this.poolAddress1)
      //   await this.cohort.leaveFromPool(this.signers[0].address, this.poolAddress1, getBigNumber(10000))
      //   let poolBalance = await riskPool.balanceOf(this.signers[0].address)
      //   expect(poolBalance).to.equal(getBigNumber(500000))

      //   const currentDate = new Date()
      //   const afterThreeDays = new Date(currentDate.setDate(currentDate.getDate() + 3))
      //   const afterThreeDaysTimeStampUTC = new Date(afterThreeDays.toUTCString()).getTime() / 1000

      //   network.provider.send("evm_setNextBlockTimestamp", [afterThreeDaysTimeStampUTC])
      //   await network.provider.send("evm_mine")

      //   await expect(this.cohort.leaveFromPool(this.signers[0].address, this.poolAddress1, getBigNumber(10000))).to.be.revertedWith("UnoRe: rebalance period")
      //   poolBalance = await riskPool.balanceOf(this.signers[0].address)
      //   expect(poolBalance).to.equal(getBigNumber(500000))
      // })

      // it("Should buy policy and then check policy holder's usdc balance", async function () {
      //   this.salesPolicy1 = new ethers.Contract(this.salesPolicyAddress1, JSON.stringify(SalesPolicy.abi), ethers.provider)

      //   // origin premium balance
      //   const premiumBalanceBefore = await this.usdcContract.balanceOf(this.premiumPoolAddress)
      //   expect(getNumber(premiumBalanceBefore, 6)).to.equal(200000)

      //   // origin policy holder's balance before buy policy
      //   const holderUSDCBalanceBefore = await this.usdcContract.balanceOf(this.signers[0].address)

      //   const premiumFactor = await this.cohort.getProtocolPremiumFactor(0);
      //   const premiumPaid = (getBigNumber(100000, 6).mul(premiumFactor).mul(BigNumber.from(24 * 3600 * 30).div(BigNumber.from(24 * 3600 * 5)))).div(73).div(1000);

      //   // buy policy in protocol 1
      //   await (
      //     await this.usdcContract
      //       .connect(this.signers[0])
      //       .approve(this.salesPolicyAddress1, getBigNumber(10000000000, 6), { from: this.signers[0].address })
      //   ).wait()

      //   await (
      //     await this.salesPolicy1
      //   .connect(this.signers[0]).buyPolicy(
      //     "https://xxxxx", // policy URI
      //     getBigNumber(100000, 6), // coverage amount
      //     BigNumber.from(24 * 3600 * 30), // coverage duration
      //     { from: this.signers[0].address }
      //   )).wait()

      //   const premiumBalanceAfter = await this.usdcContract.balanceOf(this.premiumPoolAddress)
      //   expect(premiumBalanceAfter).to.equal(premiumBalanceBefore.add(premiumPaid));

      //   const holderUSDCBalanceAfter = await this.usdcContract.balanceOf(this.signers[0].address)
      //   expect(holderUSDCBalanceAfter).to.equal(holderUSDCBalanceBefore.sub(premiumPaid));

      // })

      // it("Should submit withdraw request and implement withdraw requests in the rebalance period", async function () {
      //   // buy policy in protocol 1
      //   // this.salesPolicy1 = new ethers.Contract(this.salesPolicyAddress1, JSON.stringify(SalesPolicy.abi), ethers.provider)

      //   await (
      //     await this.usdcContract
      //       .connect(this.signers[0])
      //       .approve(this.salesPolicyAddress1, getBigNumber(10000000000, 6), { from: this.signers[0].address })
      //   ).wait()

      //   await (
      //     await this.salesPolicy1
      //     .connect(this.signers[0]).buyPolicy(
      //     "https://xxxxx", // policy URI
      //     getBigNumber(100000, 6), // coverage amount
      //     BigNumber.from(24 * 3600 * 30), // coverage duration
      //     { from: this.signers[0].address }
      //   )).wait()

      //   const riskPool = this.RiskPool.attach(this.poolAddress1)
      //   let stakerPoolBalance = await riskPool.balanceOf(this.signers[0].address)
      //   expect(stakerPoolBalance).to.equal(getBigNumber(500000))

      //   // send withdraw request but it will be in pending for now.
      //   await this.cohort.leaveFromPool(this.signers[0].address, this.poolAddress1, getBigNumber(10000))

      //   stakerPoolBalance = await riskPool.balanceOf(this.signers[0].address)
      //   expect(stakerPoolBalance).to.equal(getBigNumber(500000))

      //   const premiumBalanceBefore = await this.usdcContract.balanceOf(this.premiumPoolAddress)
      //   const investorUNOBalanceBefore = await this.mockUNO.balanceOf(this.signers[0].address)
      //   const investorUSDCBalanceBefore = await this.usdcContract.balanceOf(this.signers[0].address)

      //   // get total capital
      //   const totalCapital = await this.cohort.getTotalCapital();
      //   console.log("[totalCapital]", totalCapital.toString());

      //   // get total capital
      //   const totalCoveredAmount = await this.cohort.getTotalCoveredAmount();
      //   console.log("[totalCoveredAmount]", totalCoveredAmount.toString());

      //   // premium reward amount per user
      //   const premiumAmount = await this.cohort.totalPremiumReward(this.signers[0].address, this.poolAddress1);
      //   console.log("[premiumAmount]", premiumAmount.toString());

      //   const currentDate = new Date()
      //   const afterfourDays = new Date(currentDate.setDate(currentDate.getDate() + 4))
      //   const afterFourDaysTimeStampUTC = new Date(afterfourDays.toUTCString()).getTime() / 1000

      //   network.provider.send("evm_setNextBlockTimestamp", [afterFourDaysTimeStampUTC])
      //   await network.provider.send("evm_mine")

      //   // check total withdraw per pool and per user to implement really
      //   const totalWithdrawAmountPerPool = await this.cohort.totalWithdrawPerPool(this.poolAddress1);
      //   console.log("[totalWithdrawAmountPerPool]", totalWithdrawAmountPerPool.toString())
      //   const withdrawAmountPerPoolPerUser = await this.cohort.userWithdrawPerPool(this.poolAddress1, this.signers[0].address)
      //   console.log("[withdrawAmountPerPoolPerUser]", withdrawAmountPerPoolPerUser.toString())

      //   // At the next epoch time, implement withdraw requests
      //   await this.cohort.batchImplementForWithdrawRequest(this.poolAddress1)

      //   stakerPoolBalance = await riskPool.balanceOf(this.signers[0].address)
      //   expect(stakerPoolBalance).to.equal(getBigNumber(490000))

      //   // after withdraw, premium balance
      //   const premiumBalanceAfter = await this.usdcContract.balanceOf(this.premiumPoolAddress)
      //   expect(premiumBalanceAfter).to.equal(premiumBalanceBefore.sub(premiumAmount))

      //   // after withdraw investor balance
      //   const investorUNOBalanceAfter = await this.mockUNO.balanceOf(this.signers[0].address)
      //   const expectedUNOBalance = investorUNOBalanceBefore.add(getBigNumber(10000))
      //   expect(investorUNOBalanceAfter).to.not.equal(expectedUNOBalance)

      //   const investorUSDCBalanceAfter = await this.usdcContract.balanceOf(this.signers[0].address)
      //   console.log("[investorUSDCBalanceAfter]", getNumber(investorUSDCBalanceAfter, 6))
      //   const expectedUSDCBalance = investorUSDCBalanceBefore.add(premiumAmount)
      //   expect(investorUSDCBalanceAfter).to.equal(expectedUSDCBalance)

      // })

      // it("Should allow to submit withdraw request onle one time before claim processing", async function () {
      //   // send withdraw request but it will be in pending for now.
      //   await this.cohort.leaveFromPool(this.signers[0].address, this.poolAddress1, getBigNumber(10000))

      //   const currentDate = new Date()
      //   const afterThreeDays = new Date(currentDate.setDate(currentDate.getDate() + 3))
      //   const afterThreeDaysTimeStampUTC = new Date(afterThreeDays.toUTCString()).getTime() / 1000

      //   network.provider.send("evm_setNextBlockTimestamp", [afterThreeDaysTimeStampUTC])
      //   await network.provider.send("evm_mine")

      //   // During rebalance period, implement withdraw requests
      //   await this.cohort.batchImplementForWithdrawRequest(this.poolAddress1)

      //   const afterFiveDays = new Date(afterThreeDays.setDate(afterThreeDays.getDate() + 4))
      //   const afterFiveDaysTimeStampUTC = new Date(afterFiveDays.toUTCString()).getTime() / 1000
      //   network.provider.send("evm_setNextBlockTimestamp", [afterFiveDaysTimeStampUTC]) // 2021-8-31-4:1:21 pm
      //   await network.provider.send("evm_mine")

      //   await expect(this.cohort.leaveFromPool(this.signers[0].address, this.poolAddress1, getBigNumber(10000))).to.be.revertedWith("UnoRe: exists pending amount in claim queue already")

      // })

      // it("Should reject claim request before 2 epochs or expire withdraw request unless submit claim request after 3 epochs", async function () {
      //   const riskPool = this.RiskPool.attach(this.poolAddress1)
      //   // send withdraw request but it will be in pending for now.
      //   await this.cohort.leaveFromPool(this.signers[0].address, this.poolAddress1, getBigNumber(10000))

      //   const currentDate = new Date()
      //   const afterThreeDays = new Date(currentDate.setDate(currentDate.getDate() + 3))
      //   const afterThreeDaysTimeStampUTC = new Date(afterThreeDays.toUTCString()).getTime() / 1000

      //   network.provider.send("evm_setNextBlockTimestamp", [afterThreeDaysTimeStampUTC])
      //   await network.provider.send("evm_mine")

      //   // During rebalance period, implement withdraw requests
      //   await this.cohort.batchImplementForWithdrawRequest(this.poolAddress1)

      //   // next new epoch
      //   const afterFourDays = new Date(afterThreeDays.setDate(afterThreeDays.getDate() + 3))
      //   const afterFourDaysTimeStampUTC = new Date(afterFourDays.toUTCString()).getTime() / 1000
      //   network.provider.send("evm_setNextBlockTimestamp", [afterFourDaysTimeStampUTC])
      //   await network.provider.send("evm_mine")

      //   const claimAmountBefore = await riskPool.withdrawalClaimRequestAmountPerUser(this.signers[0].address);
      //   expect(claimAmountBefore).to.equal(getBigNumber(10000))

      //   await expect(this.cohort.withdrawClaimRequest(this.poolAddress1, this.signers[0].address)).to.be.revertedWith("UnoRe: no claim time yet")

      //   // In the rebalance period after 2 epochs
      //   const afterTwoEpoch = new Date(afterFourDays.setDate(afterFourDays.getDate() + 12))
      //   const afterTwoEpochsTimeStampUTC = new Date(afterTwoEpoch.toUTCString()).getTime() / 1000
      //   network.provider.send("evm_setNextBlockTimestamp", [afterTwoEpochsTimeStampUTC])
      //   await network.provider.send("evm_mine")

      //   // During rebalance period, implement withdraw requests
      //   await this.cohort.batchImplementForWithdrawRequest(this.poolAddress1)

      //   const claimAmountAfter = await riskPool.withdrawalClaimRequestAmountPerUser(this.signers[0].address);
      //   expect(claimAmountAfter).to.equal(0)

      //   // after 3 epochs
      //   const afterThreeDaysSecond = new Date(afterTwoEpoch.setDate(afterTwoEpoch.getDate() + 3))
      //   const afterThreeDaysSecondTimeStampUTC = new Date(afterThreeDaysSecond.toUTCString()).getTime() / 1000
      //   network.provider.send("evm_setNextBlockTimestamp", [afterThreeDaysSecondTimeStampUTC])
      //   await network.provider.send("evm_mine")

      //   await expect(this.cohort.withdrawClaimRequest(this.poolAddress1, this.signers[0].address)).to.be.revertedWith("UnoRe: expired claim request")
      // })

      // it("Should leave with expected amount", async function () {
      //   const riskPool = this.RiskPool.attach(this.poolAddress1)
      //   // buy policy in protocol 1
      //   const protocol1 = await this.cohort.getProtocol(0);
      //   const salesPolicyContract1 = new ethers.Contract(protocol1.salesPolicy, JSON.stringify(SalesPolicy.abi), ethers.provider)

      //   await (
      //     await this.usdcContract
      //       .connect(this.signers[0])
      //       .approve(salesPolicyContract1.address, getBigNumber(10000000, 6), { from: this.signers[0].address })
      //   ).wait()

      //   await (
      //     await salesPolicyContract1
      //   .connect(this.signers[0]).buyPolicy("https://xxxxx", getBigNumber(100000, 6), BigNumber.from(24 * 3600 * 30), { from: this.signers[0].address })
      //   ).wait()

      //   const balanceUnoBefore = await this.mockUNO.balanceOf(this.signers[0].address)
      //   const balanceUSDCBefore = await this.usdcContract.balanceOf(this.signers[0].address)

      //   // send withdraw request
      //   await this.cohort.leaveFromPool(this.signers[0].address, this.poolAddress1, getBigNumber(100000))

      //   const currentDate = new Date()
      //   const afterThreeDays = new Date(currentDate.setDate(currentDate.getDate() + 3))
      //   const afterThreeDaysTimeStampUTC = new Date(afterThreeDays.toUTCString()).getTime() / 1000
      //   network.provider.send("evm_setNextBlockTimestamp", [afterThreeDaysTimeStampUTC])
      //   await network.provider.send("evm_mine")

      //   // calc expected benefit
      //   const stakedAmount1 = await riskPool.balanceOf(this.signers[0].address)
      //   const usdcPrice = await this.priceAgent.getLatestPrice("USDC")
      //   const unoPrice = await this.priceAgent.getLatestPrice("UNO")

      //   // const apr1 = await riskPool1.APR()
      //   const poolLength = await this.cohort.allRiskPoolLength()
      //   let totalCapital = BigNumber.from(0);
      //   let premiumReward = BigNumber.from(0);
      //   for(let i = 0; i < poolLength; i++) {
      //     const riskPools = this.RiskPool.attach(this.cohort.getRiskPool(i))
      //     const poolCapital = await riskPools.totalSupply()
      //     totalCapital = totalCapital.add(poolCapital.mul(unoPrice))
      //   }

      //   const poolTolerance = await this.cohort.poolRiskTolerance(this.poolAddress1)
      //   const poolCapital1 = await riskPool.totalSupply()
      //   const protocolLength = await this.cohort.allProtocolsLength()

      //   for (let ii = 0; ii < protocolLength; ii++) {
      //     const protocol = await this.cohort.getProtocol(ii);
      //     const salesPolicyContract = new ethers.Contract(protocol.salesPolicy, JSON.stringify(SalesPolicy.abi), ethers.provider)

      //     const policyLength = await salesPolicyContract.allPoliciesLength()
      //     let _tr = BigNumber.from(0)
      //     for(let kk = 0; kk < policyLength; kk++) {
      //       const policyIdx = await salesPolicyContract.getPolicyIdx(kk)
      //       const policyDetail = await salesPolicyContract.policyDetail(policyIdx)
      //       const startEpoch = await this.cohort.checkEpochStatus(policyDetail[3])
      //       const currentEpoch = await this.cohort.checkEpochStatus(afterThreeDaysTimeStampUTC)

      //       const epochNumberInCoverage = currentEpoch[0].add(1).sub(startEpoch[0])
      //       if (epochNumberInCoverage > 0) {
      //         const policyPaid = policyDetail[4].mul(usdcPrice)
      //         _tr = _tr.add(policyPaid.div(epochNumberInCoverage))
      //       }
      //     }
      //     premiumReward = premiumReward.add((poolTolerance.mul(_tr).mul(stakedAmount1)).div(poolCapital1).div(1000))
      //   }

      //   // expected withdrawl volumn from risk pool
      //   const returnFromStake = getBigNumber(100000)
      //   // const totalWithdraw = premiumReward.add(returnFromStake)

      //   // At the first next epoch time, implement deposit requests.
      //   await this.cohort.batchImplementForWithdrawRequest(this.poolAddress1)

      //   const newEpoch = new Date(afterThreeDays.setDate(afterThreeDays.getDate() + 12))
      //   const newEpochTimeStampUTCSecond = new Date(newEpoch.toUTCString()).getTime() / 1000

      //   network.provider.send("evm_setNextBlockTimestamp", [newEpochTimeStampUTCSecond])
      //   await network.provider.send("evm_mine")

      //   // At the second next epoch time, implement withdraw requests
      //   await this.cohort.withdrawClaimRequest(this.poolAddress1, this.signers[0].address)

      //   const balanceUNOAfter = await this.mockUNO.balanceOf(this.signers[0].address)

      //   expect(balanceUnoBefore.add(returnFromStake)).to.equal(balanceUNOAfter)

      //   const balanceUSDCAfter = await this.usdcContract.balanceOf(this.signers[0].address)
      //   expect(balanceUSDCBefore.add(premiumReward.div(10**8))).to.equal(balanceUSDCAfter)
      // })

      it("Should not allow others to claim except claimAssessor", async function () {
        await expect(this.cohort.requestClaim(this.signers[2].address, 0, getBigNumber(10000))).to.be.revertedWith(
          "UnoRe: Forbidden",
        )
      })

      it("Should claim revert with insufficient amount", async function () {
        await expect(
          this.claimAssessor.requestClaim(this.signers[1].address, this.cohort.address, 0, getBigNumber(1000000000)),
        ).to.be.revertedWith("UnoRe: Capital is not enough")
      })

      it("Should request claim and get amount", async function () {
        const balanceBefore = await this.mockUNO.balanceOf(this.signers[1].address)
        const balanceUSDCBefore = await this.usdcContract.balanceOf(this.signers[1].address)
        let premiumUSDCBalanceBefore = await this.usdcContract.balanceOf(this.premiumPoolAddress)

        // get claim amount from premium (requesst claim for protocol 1)
        // premium balance 200000 - 100000 for the protocol 1, minimum 1000 => 200000 - 50000 = 150000
        await this.claimAssessor.requestClaim(this.signers[1].address, this.cohort.address, 0, getBigNumber(50000, 6))
        const balanceAfter = await this.mockUNO.balanceOf(this.signers[1].address)
        const balanceUSDCAfter = await this.usdcContract.balanceOf(this.signers[1].address)
        let premiumUSDCBalanceAfter = await this.usdcContract.balanceOf(this.premiumPoolAddress)
        expect(balanceAfter).to.equal(balanceBefore)
        expect(premiumUSDCBalanceAfter).to.equal(premiumUSDCBalanceBefore.sub(getBigNumber(50000, 6)))
        expect(balanceUSDCAfter).to.equal(balanceUSDCBefore.add(getBigNumber(50000, 6)))

        // get claim amount from premium and Risk Pool1
        // premium balance for the protocol 1 50000, minimum 1000 => 50000 - 1000 = 49000 => 100000 - 49000 = 51000 => from risk pool
        const poolBalanceBefore = await this.mockUNO.balanceOf(this.poolAddress1)
        premiumUSDCBalanceBefore = await this.usdcContract.balanceOf(this.premiumPoolAddress)
        await this.claimAssessor.requestClaim(this.signers[1].address, this.cohort.address, 0, getBigNumber(100000, 6))
        const poolBalanceAfter = await this.mockUNO.balanceOf(this.poolAddress1)
        premiumUSDCBalanceAfter = await this.usdcContract.balanceOf(this.premiumPoolAddress)
        const usdcPrice = await this.priceAgent.getLatestPrice("USDC")
        const unoPrice = await this.priceAgent.getLatestPrice("UNO")
        const otherClaimForPool = usdcPrice.mul(getBigNumber(51000, 6))
        const poolTolerance = await this.cohort.poolRiskTolerance(this.poolAddress1)
        const unoClaimAmount = otherClaimForPool.div(unoPrice)
        const realClaimAmount = unoClaimAmount.mul(poolTolerance).div(1000)
        expect(premiumUSDCBalanceAfter).to.equal(premiumUSDCBalanceBefore.sub(getBigNumber(49000, 6)))
        expect(poolBalanceBefore).to.equal(poolBalanceAfter.add(BigNumber.from(realClaimAmount)))
      })
    })
  })
})
