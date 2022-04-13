// Defining bytecode and abi from original contract on mainnet to ensure bytecode matches and it produces the same pair code hash

module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const claimAssessor = await deployments.get("ClaimAssessor");
  console.log("[claimAssessor]", claimAssessor.address);
  await deploy('Actuary', {
    from: deployer,
    args: [claimAssessor.address],
    log: true,
    deterministicDeployment: false,
  })
}

module.exports.tags = ["Actuary", "UnoRe"];
