pragma solidity ^0.4.18;

import "../interfaces/IStorage.sol";
import "./PDelegate.sol";

contract PLock is PDelegate {

  function () payable public {
    address s = 0xa0ed9a40aac5831a39a25f6aba30542e68d6d37f;
    address target = IStorage(s).getAddress(keccak256("LLockInstance"));

    require (target > 0);

    delegatedFwd(target, msg.data);
  }
  
}