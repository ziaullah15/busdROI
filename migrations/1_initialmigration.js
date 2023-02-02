// const NFT = artifacts.require("NFT");
// const tkn = artifacts.require("ZiaToken");
const stake = artifacts.require("staking");
const tknadd = '0x75d4cd4fa827EFBfeE37F7839c1dE46b58881827'
const owneradd = '0x5B38Da6a701c568545dCfcB03FcB875f56beddC4'
const marketadd = '0xdD870fA1b7C4700F2BD7f44238821C26f7392148'
// const NFT = '0x7013cFC580f84a96fcBC2Ea1EB090a3c4Fe96e7e'
// const TBL = '0x641F00FCF65461852Dd6B74dc1df16F06f30EC0D'
module.exports = function (deployer) {
  // deployer.deploy(NFT);
//   deployer.deploy(tkn);
  deployer.deploy(stake, tknadd, owneradd, marketadd);
};