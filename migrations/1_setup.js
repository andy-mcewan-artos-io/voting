var Migrations = artifacts.require("./Migrations.sol");
var Storage = artifacts.require("./Storage.sol");
var Vote = artifacts.require("./AventusVote.sol");
var LVote = artifacts.require("./libraries/LVote.sol");
var LLock = artifacts.require("./libraries/LLock.sol");

module.exports = function(deployer, network, accounts) {
  var addrLVote, addrLLock;

  var s = Storage.at("0xa0ed9a40aac5831a39a25f6aba30542e68d6d37f");
  var avt = "0x0c83963bdf21858661415c478d39fa7dbd48a991";
  
  deployer.deploy(Migrations).then(function() {
    return deployer.deploy(LVote);
  }).then(function() {
    return deployer.deploy(LLock);
  }).then(function() {
    return deployer.deploy(PVote, s.address);
  }).then(function() {
    return deployer.deploy(PLock, s.address);
  }).then(function() {
    addrLVote = LVote.address;
    addrLLock = LLock.address;

    // Link to the proxy not the actual implementation
    LVote.address = PVote.address;
    LLock.address = PLock.address;

    deployer.link(LVote, Vote);
    deployer.link(LLock, Vote);

    return deployer.deploy(Vote, s.address);
  }).then(function() {
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
