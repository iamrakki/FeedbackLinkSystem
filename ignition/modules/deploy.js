const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // Deploy the FeedbackLinkSystem contract as a proxy
  const FeedBackLinkSystem = await ethers.getContractFactory("FeedbackLinkSystem");
  const feedbackLinkSystem = await upgrades.deployProxy(FeedBackLinkSystem, [], { initializer: 'initialize' });
  await feedbackLinkSystem.waitForDeployment();
  console.log("FeedbackLinkSystem proxy deployed to:", feedbackLinkSystem.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });