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
    var avt = "0x2c2b6afed68b69cc6afd108b624884decd9129e6";

    return s.setAddress(web3.sha3("AVT"), avt);
  }).then(function() {
    return s.setOwner(Vote.address);
  });
};
