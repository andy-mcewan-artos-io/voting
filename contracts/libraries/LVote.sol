pragma solidity ^0.4.18;

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
  * @param creator Address creating the proposal
  * @param desc Either just a title or a pointer to IPFS details
  * @return uint ID of newly created proposal
  */
  function createVote(IStorage s, address creator, string desc)
    public
    returns (uint)
  {
    uint voteCount = s.getUInt(keccak256("VoteCount"));
    uint id = voteCount + 1;

    s.setString(keccak256("Vote", id, "description"), desc);
    s.setUInt(keccak256("VoteCount"), id);
    s.setAddress(keccak256("Vote", id, "creator"), creator);

    return id;
  }

  /** 
  * @dev Add an option to a proposal that voters can choose
  * @param s Storage contract
  * @param id Proposal ID
  * @param option Description of option
  */
  function addVoteOption(IStorage s, uint id, string option)
    public
    isStatus(s, id, 0)
  {
    uint count = s.getUInt(keccak256("Vote", id, "OptionsCount"));

    // Cannot add more than 4 options
    require (count < 5);

    // Store new options count, and the option + description
    s.setString(keccak256("Vote", id, "option", count + 1), option);
    s.setUInt(keccak256("Vote", id, "OptionsCount"), count + 1);
  }

  /** 
  * @dev Finish setting up votes with time intervals & start
  * @param s Storage contract
  * @param id Proposal ID
  * @param start The start date of the cooldown period, after which vote starts
  * @param interval The amount of time the vote and reveal periods last for
  */
  function finaliseVote(IStorage s, uint id, uint start, uint interval)
    public
    isStatus(s, id, 0)
  {
    // Make sure start is afer now and that interval is at least a week
    require (start >= now && interval >= 7 days);

    uint optionCount = s.getUInt(keccak256("Vote", id, "OptionsCount"));

    // Make sure there are more than 2 options to vote on
    require (optionCount >= 2);

    // Cooldown period start, which is always twice the voting interval length
    uint votingStart = start + 2 * interval;
    uint revealingStart = votingStart + interval;
    uint end = revealingStart + interval;

    s.setUInt(keccak256("Vote", id, "votingStart"), votingStart);
    s.setUInt(keccak256("Vote", id, "revealingStart"), revealingStart);
    s.setUInt(keccak256("Vote", id, "end"), end);
  }

  /** 
  * @dev Cast a vote on one of a given proposal's options
  * @param s Storage contract
  * @param id Proposal ID
  * @param voter Address of the voter
  * @param secret The secret vote: Sha3(signed Sha3(option ID))
  * @param prevTime The previous revealStart time that locked the user's funds
  * @param prevId The previous proposal ID at the current revealStart time
  */
  function castVote(
    IStorage s, 
    uint id,
    address voter, 
    bytes32 secret,  // Sign the option id and hash the signature
    uint prevTime // The previous revealStart in the doubly linked list
  ) 
    public
    isStatus(s, id, 2) // Ensure voting period is currently active
  {
    // The current proposal's start of the reveal time
    uint time = s.getUInt(keccak256("Vote", id, "revealingStart"));
    // The next revealStart referenced by the user's previous revealStart time
    uint nextTime = s.getUInt(keccak256("Voting", voter, prevTime, "nextTime"));
    // the secret stored for the vote with id
    bytes32 currSecret = s.getBytes32(keccak256("Voting", voter, "secrets", id));
    // the number of votes currently relvealing at time
    uint currVotes = s.getUInt(keccak256("Voting", voter, "count", time));

    // Ensure prevTime passed in is correct and that user hasn't yet voted
    require (time > prevTime && (nextTime == 0 || time <= nextTime) && currSecret == 0);

    // If no items insterted at time, create new node in list
    if (currVotes == 0) {
      // Create new entry
      s.setUInt(keccak256("Voting", voter, time, "prevTime"), prevTime);
      s.setUInt(keccak256("Voting", voter, time, "nextTime"), nextTime);
      s.setUInt(keccak256("Voting", voter, prevTime, "nextTime"), time);
      s.setUInt(keccak256("Voting", voter, nextTime, "prevTime"), time);
    }

    // Save the secret vote for the user and proposal
    s.setBytes32(keccak256("Voting", voter, "secrets", id), secret);
    s.setUInt(keccak256("Voting", voter, "count", time), currVotes + 1);
  }

  /** 
  * @dev Reveal a vote on a proposal
  * @param s Storage contract
  * @param id Proposal ID
  * @param optId ID of option that was voted on
  * @param v User's ECDSA signature(keccak256(optID)) v value
  * @param r User's ECDSA signature(keccak256(optID)) r value
  * @param s_ User's ECDSA signature(keccak256(optID)) s value
  */
  function revealVote(IStorage s, uint id, uint optId, uint8 v, bytes32 r, bytes32 s_)  public {
    // Make sure proposal status is Reveal or end
    require (getVoteStatus(s, id) >= 3);

    // Web3.js sign(msg) prefixes msg with the below 
    bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    bytes32 prefixedMsg = keccak256(prefix, keccak256(optId));

    // Get voter public key from message and ECDSA components
    address voter = ecrecover(prefixedMsg, v, r, s_);
    // Get proposal revealStart
    uint time = s.getUInt(keccak256("Vote", id, "revealingStart"));
    // Get the voter's secret vote for the given proposal
    bytes32 secret = s.getBytes32(keccak256("Voting", voter, "secrets", id));
    // Make sure the original vote is the same as the reveal
    require (secret == keccak256(uint(v), r, s_));

    // Unlock the user's AVT stake for this proposal
    updateList(s, voter, time, id);

    // Key to current voteCount for the optId for the given proposal
    bytes32 key = keccak256("Vote", id, "option", optId);
    // Increment the vote count of the option by the AVT stake of voter
    s.setUInt(key, s.getUInt(key) + s.getUInt(keccak256("Lock", voter)));
  }

  /** 
  * @dev Update the doubly linked list after reveal
  * @param s Storage contract
  * @param voter the Voter whose list to update
  * @param time revealStart time of proposal
  * @param id Proposal ID
  */
  function updateList(IStorage s, address voter, uint time, uint id) private {
    uint currVotes = s.getUInt(keccak256("Voting", voter, "count", time));

    // remove time entry if proposal ID was the only one with that revealStart
    if (currVotes == 1) {
      uint prevTime = s.getUInt(keccak256("Voting", voter, time, "prevTime"));
      uint nextTime = s.getUInt(keccak256("Voting", voter, time, "nextTime"));
      
      s.setUInt(keccak256("Voting", voter, prevTime, "nextTime"), nextTime);
      s.setUInt(keccak256("Voting", voter, nextTime, "nextTime"), prevTime);
    }
    
    s.deleteBytes32(keccak256("Voting", voter, "secrets", id), secret);
    s.setUInt(keccak256("Voting", voter, "count", time), currVotes - 1);
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
    uint votingStart = s.getUInt(keccak256("Vote", id, "votingStart"));
    uint revealingStart = s.getUInt(keccak256("Vote", id, "revealingStart"));
    uint end = s.getUInt(keccak256("Vote", id, "end"));

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
