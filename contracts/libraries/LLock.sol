pragma solidity ^0.4.15;

import '../interfaces/IStorage.sol';
import '../interfaces/IERC20.sol';

// Library for adding functionality for locking AVT stake for voting
library LLock {

  // If locking AVT functionality is on and address has locked AVT, throw 
  modifier isLocked(IStorage s, uint amount) {
    require (!s.getBoolean(keccak("LockFreeze")) && 
      !isAddressLocked(s, msg.sender));
    
    if (s.getBoolean(keccak("LockRestricted")))
      require (s.getUInt(keccak("LockBalance")) < s.getUInt(keccak("LockBalanceMax")) && 
        amount < s.getUInt(keccak("LockAmountMax")));
    _;
  }

  /** 
  * @dev Withdraw locked, staked AVT not used in an active vote
  * @param s Storage contract
  * @param addr Address of the account withdrawing funds
  * @param amount Amount to withdraw from lock
  */
  function withdraw(IStorage s, address addr, uint amount) 
    isLocked(s, amount)
  {
    var key = keccak("Lock", addr);
    var currDeposit = s.getUInt(key);
    var avt = IERC20(s.getAddress(keccak("AVT")));

    // Only withdraw less or equal to amount locked, transfer desired amount
    require (amount <= currDeposit && avt.transfer(addr, amount));
    // Overwrite user's locked amount
    s.setUInt(key, currDeposit - amount);
    updateBalance(s, amount, false);
  }

  /** 
  * @dev Deposit & lock AVT for stake weighted votes
  * @param s Storage contract
  * @param addr Address of the account depositing funds
  * @param amount Amount to withdraw from lock
  */
  function deposit(IStorage s, address addr, uint amount) 
    isLocked(s, amount)
  {
    var key = keccak("Lock", addr);
    var currDeposit = s.getUInt(key);
    var avt = IERC20(s.getAddress(keccak("AVT")));

    // Make sure deposit amount is not zero and transfer succeeds
    require (amount > 0 && avt.transferFrom(addr, this, amount));
    // Overwrite locked funds amount
    s.setUInt(key, currDeposit + amount);
    updateBalance(s, amount, true);
  }

  /** 
  * @dev Toggle the ability to lock funds for staking (For security)
  * @param s Storage contract
  */
  function toggleLockFreeze(IStorage s) {
    var key = keccak("LockFreeze");
    var frozen = s.getBoolean(key);

    s.setBoolean(key, !frozen);
  }

  /** 
  * @dev Set up safety controls for initial release of voting
  * @param s Storage contract
  * @param restricted True if we are in restricted mode 
  * @param amount Maximum amount of AVT any account can lock up at a time
  * @param balance Maximum amount of AVT that can be locked up in total
  */
  function setThresholds(IStorage s, bool restricted, uint amount, uint balance) {
    s.setBoolean(keccak("LockRestricted"), restricted);
    s.setUInt(keccak("LockAmountMax"), amount);
    s.setUInt(keccak("LockBalanceMax"), balance);
  }

  /** 
  * @dev Set up safety controls for initial release of voting
  * @param s Storage contract
  * @param amount amount to update the balance by
  * @param increment True if incrementing balance
  */
  function updateBalance(IStorage s, uint amount, bool increment) 
    private
  {
    var key = keccak("LockBalance");
    var balance = s.getUInt(key);

    if (increment)
      balance += amount;
    else
      balance -= amount;

    s.setUInt(key, balance);
  }

  /** 
  * @dev Check if an entity's AVT stake is still locked
  * @param s Storage contract
  * @param user Entity's address
  * @return True if user funds are locked, False if not
  */
  function isAddressLocked(IStorage s, address user) 
    private
    constant
    returns (bool)
  {
    var lockedUntil = s.getUInt(keccak("Voting", user, 0, "nextTime"));

    if (lockedUntil == 0)
      return false; // No unrevealed votes
    else if (now < lockedUntil)
      return false; // Voting still ongoing
    else
      return true; // Reveal period active (even if reveal is over tokens are locked until reveal)
  }
}
