// - Mock Token
// name: USDC
// symbol: USDC

const fs = require("fs")
const { ethers } = require("hardhat")
const { BigNumber } = ethers
const hre = require("hardhat")
const { getBigNumber } = require("./shared/utilities")

const actuaryDeployment = require("../deployments/bscTest/Actuary.json")
const claimAssessorDeployment = require("../deployments/bscTest/ClaimAssessor.json")
const mockUSDTDeployment = require("../deployments/bscTest/MockUSDT.json")
const cohortFactoryDeployment = require("../deployments/bscTest/CohortFactory.json")
const premiumPoolFactoryDeployment = require("../deployments/bscTest/PremiumPoolFactory.json")
const riskPoolFactoryDeployment = require("../deployments/bscTest/RiskPoolFactory.json")

async function main() {
  const signers = await ethers.getSigners()
  console.log("[signers]", signers[0].address)
  // - Cohort
  // name: Cohort I
  // COHORT_START_CAPITAL: 500,000 USDC
  const COHORT_PARAMS = {
    name: "Cohort II",
    startCapital: 500000,
    minPremium: 5000,
  }

  // - Protol 1, 2, 3
  // Name - Umbrella Network, Tidal Finance, Rocket Vault
  // Product type: Staking Pool Cover, XOL Cover, CEX Cover
  // Premium Description: Staking Pool Cover, XOL Cover, CEX Cover
  // Cover duration: deploy the contracts with 12 hours as duration for initial testing
  const PROTOCOLS = [
    {
      name: "Umbrella Network",
      protocolAddress: signers[0].address,
      productType: "Staking Pool Cover",
      description: "Staking Pool Cover",
      coverDuration: BigNumber.from(12 * 3600), // 12 hours for testing
    },
    {
      name: "Tidal Finance",
      protocolAddress: signers[0].address,
      productType: "XOL Cover",
      description: "XOL Cover",
      coverDuration: BigNumber.from(12 * 3600), // 12 hours for testing
    },
    {
      name: "Rocket Vault",
      protocolAddress: signers[0].address,
      productType: "CEX Cover",
      description: "CEX Cover",
      coverDuration: BigNumber.from(12 * 3600), // 12 hours for testing
    },
  ]

  // - Risk Pool 1, 2, 3
  // name: Zeus, Athena, Artemis
  // size: 35,000, 165,000, 300,000 USDC
  // APR: 20%, 13%, 7%
  const RISK_POOLS = [
    {
      name: "Zeus",
      symbol: "Zeus",
      APR: 200,
      maxSize: getBigNumber(350000),
    },
    {
      name: "Athena",
      symbol: "Athena",
      APR: 130,
      maxSize: getBigNumber(350000),
    },
    {
      name: "Artemis",
      symbol: "Artemis",
      APR: 70,
      maxSize: getBigNumber(200000),
    },
  ]

  const ACTUARY_ADDRESS = actuaryDeployment.address
  const CLAIMASSESSOR_ADDRESS = claimAssessorDeployment.address
  const COHORT_FACTORY_ADDRESS = cohortFactoryDeployment.address
  const MOCK_USDT_ADDRESS = mockUSDTDeployment.address
  const PREMIUMPOOL_FACTORY_ADDRESS = premiumPoolFactoryDeployment.address
  const RISKPOOL_FACTORY_ADDRESS = riskPoolFactoryDeployment.address

  const Actuary = await ethers.getContractFactory("Actuary")
  const Cohort = await ethers.getContractFactory("Cohort")
  const Premium = await ethers.getContractFactory("PremiumPool")
  const actuary = await Actuary.attach(ACTUARY_ADDRESS)

  console.log("[actuary]", await actuary.isCohortCreator(signers[0].address))
  // Creat cohort
  console.log("Creating Cohort...")
  const createCohortTx = await actuary.createCohort(
    COHORT_FACTORY_ADDRESS,
    COHORT_PARAMS.name,
    getBigNumber(COHORT_PARAMS.startCapital),
    PREMIUMPOOL_FACTORY_ADDRESS,
    MOCK_USDT_ADDRESS,
    getBigNumber(COHORT_PARAMS.minPremium),
  )

  const cohortAddress = (await createCohortTx.wait()).events[0].args.cohort
  // const cohortAddress = "0x2eD9924C7b3c0DB5d133Edf720e943Afd2B19bCF";
  console.log("Cohort Address ==>", cohortAddress)
  const cohort = await Cohort.attach(cohortAddress)
  const premiumPoolAddress = await cohort.premiumPool()
  const cohortOwner = await cohort.owner()
  const cohortClaimAssessor = await cohort.claimAssessor()
  const cohortName = await cohort.name()
  const cohortCapital = await cohort.COHORT_START_CAPITAL()
  const premium = await Premium.attach(premiumPoolAddress)

  console.log("cohort Info =>", cohortOwner, cohortClaimAssessor, cohortName, cohortCapital)
  console.log("PremiumPool Address =>", premiumPoolAddress, await premium.currency())

  // Add protocols
  // console.log('Adding protocols...')
  for (const protocol of PROTOCOLS) {
    await cohort.addProtocol(
      protocol.name,
      signers[0].address,
      protocol.productType,
      protocol.description,
      protocol.coverDuration,
    )
  }

  // create risk pools
  console.log("Creating Risk pools...")
  for (const rp of RISK_POOLS) {
    await cohort.createRiskPool(rp.name, rp.symbol, RISKPOOL_FACTORY_ADDRESS, MOCK_USDT_ADDRESS, rp.APR, rp.maxSize)

    // Safe delay
    console.log(`Risk Pool ${rp.name} was created, delaying...`)
    for (let ii = 0; ii < 1000000; ii++) {}
  }

  console.log("Writing deploy result..")
  const content = `
    Cohort: ${cohortAddress},
  `
  await fs.writeFileSync("deploy.txt", content, { flag: "w+" })
  console.log("==END==")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
