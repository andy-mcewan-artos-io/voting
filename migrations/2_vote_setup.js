var Storage = artifacts.require("./Storage.sol");
var Vote = artifacts.require("./AventusVote.sol");
var LVote = artifacts.require("./libraries/LVote.sol");
var LLock = artifacts.require("./libraries/LLock.sol");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(Storage).then(function() {
    return deployer.deploy(LVote);
  }).then(function() {
    return deployer.deploy(LLock);
  }).then(function() {
    deployer.link(LVote, Vote);
    deployer.link(LLock, Vote);

    return deployer.deploy(Vote, Storage.address);
  }).then(function() {
    return Storage.deployed();    
  }).then(function(s) {
    console.log('export var storage = "' + Storage.address + '"');
    console.log('export var vote = "' + Vote.address + '"');
    console.log('export var storageAbi = ' + JSON.stringify(Storage.abi));
    console.log('export var voteAbi = ' + JSON.stringify(Vote.abi));

    return s.setOwner(Vote.address);
  });
};
