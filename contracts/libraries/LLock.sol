pragma solidity ^0.4.15;

import '../interfaces/IStorage.sol';
import '../interfaces/IERC20.sol';

// Library for adding functionality for locking AVT stake for voting
library LLock {

  // If locking AVT functionality is on and address has locked AVT, throw 
  modifier isLocked(IStorage s, uint amount) {
    require (!s.getBoolean(sha3("LockFreeze")) && 
      !isAddressLocked(s, msg.sender));
    
    if (s.getBoolean(sha3("LockRestricted")))
      require (s.getUInt(sha3("LockBalance")) < s.getUInt(sha3("LockBalanceMax")) && 
        amount < s.getUInt(sha3("LockAmountMax")));
    _;
  }

  /** 
  * @dev Withdraw locked, staked AVT not used in an active vote
  * @param s Storage contract
  * @param amount Amount to withdraw from lock
  */
  function withdraw(IStorage s, uint amount) 
    isLocked(s, amount)
  {
    var key = sha3("Lock", msg.sender);
    var currDeposit = s.getUInt(key);
    var avt = IERC20(s.getAddress(sha3("AVT")));

    // Only withdraw less or equal to amount locked, transfer desired amount
    require (amount <= currDeposit && avt.transfer(msg.sender, amount));
    // Overwrite user's locked amount
    s.setUInt(key, currDeposit - amount);
    updateBalance(s, amount, false);
  }

  /** 
  * @dev Deposit & lock AVT for stake weighted votes
  * @param s Storage contract
  * @param amount Amount to withdraw from lock
  */
  function deposit(IStorage s, uint amount) 
    isLocked(s, amount)
  {
    var key = sha3("Lock", msg.sender);
    var currDeposit = s.getUInt(key);
    var avt = IERC20(s.getAddress(sha3("AVT")));

    // Make sure deposit amount is not zero and transfer succeeds
    require (amount > 0 && avt.transfer(this, amount));
    // Overwrite locked funds amount
    s.setUInt(key, currDeposit + amount);
    updateBalance(s, amount, true);
  }

  /** 
  * @dev Toggle the ability to lock funds for staking (For security)
  * @param s Storage contract
  */
  function toggleLockFreeze(IStorage s) {
    var key = sha3("LockFreeze");
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
    s.setBoolean(sha3("LockRestricted"), restricted);
    s.setUInt(sha3("LockAmountMax"), amount);
    s.setUInt(sha3("LockBalanceMax"), balance);
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
    var key = sha3("LockBalance");
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
    var lockedUntil = s.getUInt(sha3("Voting", user, 0, "nextTime"));

    if (lockedUntil == 0)
      return false; // No unrevealed votes
    else if (now < lockedUntil)
      return false; // Voting still ongoing
    else
      return true; // Reveal period active (even if reveal is over tokens are locked until reveal)
  }
}
