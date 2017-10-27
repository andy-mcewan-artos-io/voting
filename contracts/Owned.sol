pragma solidity ^0.4.15;

contract Owned {
  address public owner = msg.sender;

  modifier onlyOwner {
    require (msg.sender == owner);
    _;
  }

  function setOwner(address owner_) 
    onlyOwner 
  {
    require (owner_ != 0x0);
    
    owner = owner_;
  }

  function kill(address forward)
    onlyOwner
  {
    selfdestruct(forward);
  }
}
