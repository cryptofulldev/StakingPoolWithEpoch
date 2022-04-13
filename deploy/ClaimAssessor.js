// Defining bytecode and abi from original contract on mainnet to ensure bytecode matches and it produces the same pair code hash

module.exports = async function ({ deployments }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts();

  await deploy('ClaimAssessor', {
    from: deployer,
    log: true,
    deterministicDeployment: false,
  })
}

module.exports.tags = ["ClaimAssessor", "UnoRe"];
