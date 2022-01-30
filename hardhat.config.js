require("@nomiclabs/hardhat-waffle");
const fs = require("fs");
// const privateKey = fs.readFileSync("secret/.metamaskprivatekey").toString();
// const projectId = fs.readFileSync("secret/.infuraprojectid").toString();

module.exports = {
  networks: {
    hardhat: {
      chainId: 1337,
    },
    // mumbai: {
    //   url:
    //   accounts: [privateKey]
    // }
    // mainnet: {
    //   url:
    //   accounts: [privateKey]
    // }
  },
  solidity: "0.8.4",
};
