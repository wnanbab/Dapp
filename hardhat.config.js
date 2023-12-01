require("@nomicfoundation/hardhat-toolbox");
require('hardhat-abi-exporter');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  abiExporter: {
    path: './abi',
    clear: true,
    flat: true,
  }
};
