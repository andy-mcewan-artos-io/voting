pragma solidity ^0.4.18;

import './interfaces/IStorage.sol';
import './libraries/LLock.sol';
import './libraries/LVote.sol';
import './Owned.sol';

contract AventusVote is Owned {
  modifier onlyVoteCreator(uint id) {
    require (msg.sender == s.getAddress(keccak256("Vote", id, "creator")));
    _;
  }

  IStorage public s;

  /**
  * @dev Constructor
  * @param s_ Persistent storage contract
  */
  function AventusVote(IStorage s_) public {
    s = s_;
  }

  /** 
  * @dev Withdraw locked, staked AVT not used in an active vote
  * @param amount Amount to withdraw from lock
  */
  function withdraw(uint amount) public {
    LLock.withdraw(s, msg.sender, amount);
  }

  /** 
  * @dev Deposit & lock AVT for stake weighted votes
  * @param amount Amount to withdraw from lock
  */
  function deposit(uint amount) public {
    LLock.deposit(s, msg.sender, amount);
  }

  // @dev Toggle the ability to lock funds for staking (For security)
  function toggleLockFreeze()
    public
    onlyOwner
  {
    LLock.toggleLockFreeze(s);
  }

  /** 
  * @dev Set up safety controls for initial release of voting
  * @param restricted True if we are in restricted mode 
  * @param amount Maximum amount of AVT any account can lock up at a time
  * @param balance Maximum amount of AVT that can be locked up in total
  */
  function setThresholds(bool restricted, uint amount, uint balance)
    public
    onlyOwner
  {
    LLock.setThresholds(s, restricted, amount, balance);
  }

  /** 
  * @dev Create a proposal to be voted on
  * @param desc Either just a title or a pointer to IPFS details
  * @return uint ID of newly created proposal
  */
  function createVote(string desc) public {
    LVote.createVote(s, msg.sender, desc);
  }

  /** 
  * @dev Add an option to a proposal that voters can choose
  * @param id Proposal ID
  * @param option Description of option
  */
  function addVoteOption(uint id, string option) 
    public
    onlyVoteCreator(id)
  {
    LVote.addVoteOption(s, id, option);
  }

  /** 
  * @dev Finish setting up votes with time intervals & start
  * @param id Proposal ID
  * @param start The start date of the cooldown period, after which vote starts
  * @param interval The amount of time the vote and reveal periods last for
  */
  function finaliseVote(uint id, uint start, uint interval) 
    public
    onlyVoteCreator(id)
  {
    LVote.finaliseVote(s, id, start, interval);
  }

  /** 
  * @dev Cast a vote on one of a given proposal's options
  * @param id Proposal ID
  * @param secret The secret vote: Sha3(signed Sha3(option ID))
  * @param prevTime The previous revealStart time that locked the user's funds
  * @param prevId The previous proposal ID at the current revealStart time 
  */
  function castVote(uint id, bytes32 secret, uint prevTime, uint prevId) public {
    LVote.castVote(s, id, msg.sender, secret, prevTime, prevId);
  }

  /** 
  * @dev Reveal a vote on a proposal
  * @param id Proposal ID
  * @param optId ID of option that was voted on
  * @param v User's ECDSA signature(keccak(optID)) v value
  * @param r User's ECDSA signature(keccak(optID)) r value
  * @param s_ User's ECDSA signature(keccak(optID)) s value
  */
  function revealVote(uint id, uint optId, uint8 v, bytes32 r, bytes32 s_) public {
    LVote.revealVote(s, id, optId, v, r, s_);
  }


  /** 
  * @dev Upgrade Storage if necissary
  * @param s_ New Storage instance
  */
  function updateStorage(IStorage s_) 
    public
    onlyOwner
  {
    s = s_;
  } 

  /** 
  * @dev Update the owner of the storage contract
  * @param owner_ New Owner of the storage contract
  */
  function setStorageOwner(address owner_) 
    public
    onlyOwner
  {
    Owned(s).setOwner(owner_);
  }
}
