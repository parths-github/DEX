const {CRYPTO_DEV_TOKEN_CONTRACT_ADDRESS} = require("../constants");



module.exports = async ({
    getNamedAccounts,
    deployments
}) => {
    const CryptoDevTokenAddress = CRYPTO_DEV_TOKEN_CONTRACT_ADDRESS;
    const{deploy, log} = deployments;

    const{ deployer } = await getNamedAccounts();
    const args = [CryptoDevTokenAddress];
    log(`Deploying...`);
    const Exchange = await deploy("Exchange", {
        from: deployer,
        logs: true,
        args: args
    });
    log(`Exchange contract is deployed to: ${Exchange.address}`); //0xdaf21e9fbC4Fac395Ede4603474B3747Cb2947eD
    log(`Verify with: \n npx hardhat verify --network goerli ${Exchange.address} "${args}"`);

}