pragma solidity ^0.4.15;

import './interfaces/IStorage.sol';
import './libraries/LLock.sol';
import './libraries/LVote.sol';
import './Owned.sol';

contract AventusVote is Owned {
  using LLock for IStorage;
  using LVote for IStorage;

  IStorage s;

  /**
  * @dev Constructor
  * @param s_ Persistent storage contract
  */
  function AventusVote(IStorage s_) {
    s = s_;
  }

  /** 
  * @dev Withdraw locked, staked AVT not used in an active vote
  * @param amount Amount to withdraw from lock
  */
  function withdraw(uint amount) {
    s.withdraw(amount);
  }

  /** 
  * @dev Deposit & lock AVT for stake weighted votes
  * @param amount Amount to withdraw from lock
  */
  function deposit(uint amount) {
    s.deposit(amount);
  }

  // @dev Toggle the ability to lock funds for staking (For security)
  function toggleLockFreeze()
    onlyOwner
  {
    s.toggleLockFreeze();
  }

  /** 
  * @dev Set up safety controls for initial release of voting
  * @param restricted True if we are in restricted mode 
  * @param amount Maximum amount of AVT any account can lock up at a time
  * @param balance Maximum amount of AVT that can be locked up in total
  */
  function setThresholds(bool restricted, uint amount, uint balance)
    onlyOwner
  {
    s.setThresholds(restricted, amount, balance);
  }

  /** 
  * @dev Create a proposal to be voted on
  * @param desc Either just a title or a pointer to IPFS details
  * @return uint ID of newly created proposal
  */
  function createVote(string desc) {
    s.createVote(desc);
  }

  /** 
  * @dev Add an option to a proposal that voters can choose
  * @param id Proposal ID
  * @param option Description of option
  */
  function addVoteOption(uint id, string option) {
    s.addVoteOption(id, option);
  }

  /** 
  * @dev Finish setting up votes with time intervals & start
  * @param id Proposal ID
  * @param start The start date of the cooldown period, after which vote starts
  * @param interval The amount of time the vote and reveal periods last for
  */
  function finaliseVote(uint id, uint start, uint interval) {
    s.finaliseVote(id, start, interval);
  }

  /** 
  * @dev Cast a vote on one of a given proposal's options
  * @param id Proposal ID
  * @param secret The secret vote: Sha3(signed Sha3(option ID))
  * @param prevTime The previous revealStart time that locked the user's funds
  * @param prevId The previous proposal ID at the current revealStart time 
  */
  function castVote(uint id, bytes32 secret, uint prevTime, uint prevId) {
    s.castVote(id, secret, prevTime, prevId);
  }

  /** 
  * @dev Reveal a vote on a proposal
  * @param id Proposal ID
  * @param optId ID of option that was voted on
  * @param v User's ECDSA signature(sha3(optID)) v value
  * @param r User's ECDSA signature(sha3(optID)) r value
  * @param s_ User's ECDSA signature(sha3(optID)) s value
  */
  function revealVote(uint id, uint optId, uint8 v, bytes32 r, bytes32 s_) {
    s.revealVote(id, optId, v, r, s_);
  }
}
