pragma solidity ^0.4.15;

import "../interfaces/IStorage.sol";

// Library for extending voting protocol functionality
library LVote {
  // Verify a proposal's status (1 finalised, 2 voting, 3 reveal, 4 end)
  modifier isStatus(IStorage s, uint id, uint status) {
    require (status == getVoteStatus(s, id));
    _;
  }

  /** 
  * @dev Create a proposal to be voted on
  * @param s Storage contract
  * @param desc Either just a title or a pointer to IPFS details
  * @return uint ID of newly created proposal
  */
  function createVote(IStorage s, string desc)
    returns (uint)
  {
    uint voteCount = s.getUInt(keccak("VoteCount"));
    uint id = voteCount + 1;

    s.setString(keccak("Vote", id, "description"), desc);
    s.setUInt(keccak("VoteCount"), voteCount + 1);

    return id;
  }

  /** 
  * @dev Add an option to a proposal that voters can choose
  * @param s Storage contract
  * @param id Proposal ID
  * @param option Description of option
  */
  function addVoteOption(IStorage s, uint id, string option)
    isStatus(s, id, 0)
  {
    var count = s.getUInt(keccak("Vote", id, "OptionsCount"));

    // Cannot add more than 4 options
    require (count < 5);

    // Store new options count, and the option + description
    s.setString(keccak("Vote", id, "option", count + 1), option);
    s.setUInt(keccak("Vote", id, "OptionsCount"), count + 1);
  }

  /** 
  * @dev Finish setting up votes with time intervals & start
  * @param s Storage contract
  * @param id Proposal ID
  * @param start The start date of the cooldown period, after which vote starts
  * @param interval The amount of time the vote and reveal periods last for
  */
  function finaliseVote(IStorage s, uint id, uint start, uint interval)
    isStatus(s, id, 0)
  {
    // Make sure start is afer now and that interval is at least a week
    require (start >= now && interval >= 7 days);

    var optionCount = s.getUInt(keccak("Vote", id, "OptionsCount"));

    // Make sure there are more than 2 options to vote on
    require (optionCount > 2);

    // Cooldown period start, which is always twice the voting interval length
    var votingStart = start + 2 * interval;
    var revealingStart = votingStart + interval;
    var end = revealingStart + interval;

    s.setUInt(keccak("Vote", id, "votingStart"), votingStart);
    s.setUInt(keccak("Vote", id, "revealingStart"), revealingStart);
    s.setUInt(keccak("Vote", id, "end"), end);
  }

  /** 
  * @dev Cast a vote on one of a given proposal's options
  * @param s Storage contract
  * @param id Proposal ID
  * @param secret The secret vote: Sha3(signed Sha3(option ID))
  * @param prevTime The previous revealStart time that locked the user's funds
  * @param prevId The previous proposal ID at the current revealStart time
  */
  function castVote(
    IStorage s, 
    uint id, 
    bytes32 secret,  // Sign the option id and hash the signature
    uint prevTime, // The previous revealStart in the doubly linked list
    uint prevId // The previous proposal ID that also has prevTime = revealStart
  ) 
    // Ensure voting period is currently active
    isStatus(s, id, 2)
  {
    // The current proposal's start of the reveal time
    var time = s.getUInt(keccak("Vote", id, "revealingStart"));
    // The next revealStart referenced by the user's previous revealStart time
    var nextTime = s.getUInt(keccak("Voting", msg.sender, prevTime, "nextTime"));
    // Next proposal referenced by prev proposalId w/ prevTime = revealStart
    var nextId = s.getUInt(keccak("Voting", msg.sender, prevTime, "secrets", prevId, "nextId"));

    // Ensure prevTime passed in is correct and that user hasn't yet voted on 
    // this proposal
    require (time > prevTime && time <= nextTime && id > prevId && id < nextId);

    // If revealStart time is less than next revealStart, insert new item into
    // doubly linked list
    if (time != nextTime) {
      // Create new entry
      s.setUInt(keccak("Voting", msg.sender, time, "prevTime"), prevTime);
      s.setUInt(keccak("Voting", msg.sender, time, "nextTime"), nextTime);
      s.setUInt(keccak("Voting", msg.sender, prevTime, "nextTime"), time);
      s.setUInt(keccak("Voting", msg.sender, nextTime, "prevTime"), time);
    }
    // for the given revealStart item, in the next proposal ID doubly linked list
    // Insert a new item for this proposal
    s.setUInt(keccak("Voting", msg.sender, time, "secrets", id, "prevId"), prevId);
    s.setUInt(keccak("Voting", msg.sender, time, "secrets", id, "nextId"), nextId);
    s.setUInt(keccak("Voting", msg.sender, time, "secrets", prevId, "nextId"), id);
    s.setUInt(keccak("Voting", msg.sender, time, "secrets", nextId, "prevId"), id);

    // Save the secret vote for the user and proposal
    s.setBytes32(keccak("Voting", msg.sender, time, "secrets", id, "secret"), secret);
  }

  /** 
  * @dev Reveal a vote on a proposal
  * @param s Storage contract
  * @param id Proposal ID
  * @param optId ID of option that was voted on
  * @param v User's ECDSA signature(keccak(optID)) v value
  * @param r User's ECDSA signature(keccak(optID)) r value
  * @param s_ User's ECDSA signature(keccak(optID)) s value
  */
  function revealVote(IStorage s, uint id, uint optId, uint8 v, bytes32 r, bytes32 s_) {
    // Make sure proposal status is Reveal or end
    require (getVoteStatus(s, id) >= 3);
    // Get voter public key from message and ECDSA components
    var voter = ecrecover(keccak(optId), v, r, s_);
    // Get proposal revealStart
    var time = s.getUInt(keccak("Vote", id, "revealingStart"));
    // Get the voter's secret vote for the given proposal
    var secret = s.getBytes32(keccak("Voting", voter, time, "secrets", id, "secret"));
    // Make sure the original vote is the same as the reveal
    require (secret == keccak(v, r, s_));

    // Unlock the user's AVT stake for this proposal
    updateList(s, voter, time, id);

    // Key to current voteCount for the optId for the given proposal
    var key = keccak("Vote", id, "option", optId);
    // Increment the vote count of the option by the AVT stake of voter
    s.setUInt(key, s.getUInt(key) + s.getUInt(keccak("Lock", voter)));
  }

  /** 
  * @dev Update the doubly linked list after reveal
  * @param s Storage contract
  * @param voter the Voter whose list to update
  * @param time revealStart time of proposal
  * @param id Proposal ID
  */
  function updateList(IStorage s, address voter, uint time, uint id) 
    private
    constant
  {
    var prevId = s.getUInt(keccak("Voting", voter, time, "secrets", id, "prevId"));
    var nextId = s.getUInt(keccak("Voting", voter, time, "secrets", id, "nextId"));

    // remove time entry if proposal ID was the only one with that revealStart
    if (prevId == nextId) {
      var prevTime = s.getUInt(keccak("Voting", voter, time, "prevTime"));
      var nextTime = s.getUInt(keccak("Voting", voter, time, "nextTime"));
      s.setUInt(keccak("Voting", msg.sender, prevTime, "nextTime"), nextTime);
      s.setUInt(keccak("Voting", msg.sender, nextTime, "nextTime"), prevTime);
    }
    // remove secret entry if time entry still has other secrets
    else {
      s.setUInt(keccak("Voting", voter, time, "secrets", prevId, "nextId"), nextId);
      s.setUInt(keccak("Voting", voter, time, "secrets", nextId, "prevId"), prevId);
    }
  }

  /** 
  * @dev Gets a given proposal's current status
  * @param s Storage contract
  * @param id Proposal ID
  * @return Status number: 1 finalised, 2 voting, 3 reveal, 4 end
  */
  function getVoteStatus(IStorage s, uint id) 
    private
    constant
    returns (uint8) 
  {
    var votingStart = s.getUInt(keccak("Vote", id, "votingStart"));
    var revealingStart = s.getUInt(keccak("Vote", id, "revealingStart"));
    var end = s.getUInt(keccak("Vote", id, "end"));

    if (votingStart == 0)
      return 0;
    else if (now < votingStart)
      return 1; // Finalised
    else if (now >= votingStart && now < revealingStart)
      return 2; // Voting Active
    else if (now >= revealingStart && now < end)
      return 3; // Revealing Active
    else if (now >= end)
      return 4; // End
  }
}
