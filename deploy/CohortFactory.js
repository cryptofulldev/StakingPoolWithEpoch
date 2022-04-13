// Defining bytecode and abi from original contract on mainnet to ensure bytecode matches and it produces the same pair code hash

module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const actuary = await deployments.get("Actuary");

  await deploy('CohortFactory', {
    from: deployer,
    args: [actuary.address],
    log: true,
    deterministicDeployment: false,
  })
}

module.exports.tags = ["CohortFactory", "UnoRe"]
