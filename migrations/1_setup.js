var Migrations = artifacts.require("./Migrations.sol");
var Storage = artifacts.require("./Storage.sol");
var Vote = artifacts.require("./AventusVote.sol");
var LVote = artifacts.require("./libraries/LVote.sol");
var LLock = artifacts.require("./libraries/LLock.sol");

module.exports = function(deployer, network, accounts) {
  var s;
  
  deployer.deploy(Migrations).then(function() {
    return deployer.deploy(Storage);
  }).then(function() {
    return deployer.deploy(LVote);
  }).then(function() {
    return deployer.deploy(LLock);
  }).then(function() {
    deployer.link(LVote, Vote);
    deployer.link(LLock, Vote);

    return deployer.deploy(Vote, Storage.address);
  }).then(function() {
    return Storage.deployed();    
  }).then(function(s_) {
    s = s_;
    var avt = "0x0d88ed6e74bbfd96b831231638b66c05571e824f";

    console.log("Setting AVT = " + avt);

    return s.setAddress(web3.sha3("AVT"), avt);
  }).then(function() {
    return s.setBoolean(web3.sha3("LockRestricted"), true);
  }).then(function() {
    return s.setUInt(web3.sha3("LockAmountMax"), web3.toWei(1, 'ether'));
  }).then(function() {
    return s.setUInt(web3.sha3("LockBalanceMax"), web3.toWei(1000, 'ether'));
  }).then(function() {
    return s.setOwner(Vote.address);
  });
};
