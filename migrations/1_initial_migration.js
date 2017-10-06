var Migrations = artifacts.require("./Migrations.sol");
var CWPayroll = artifacts.require("./CWPayroll.sol");
var ABCToken = artifacts.require("./ABCToken.sol");
var DEFToken = artifacts.require("./DEFToken.sol");
var GHIToken = artifacts.require("./GHIToken.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  
  deployer.deploy(ABCToken);
  deployer.deploy(DEFToken);
  deployer.deploy(GHIToken);
  deployer.deploy(CWPayroll);
};
