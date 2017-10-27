pragma solidity ^0.4.15;

contract IStorage {
  mapping(bytes32 => uint) UInt;

  function getUInt(bytes32 record) 
    constant 
    returns (uint);

  function setUInt(bytes32 record, uint value);

  function deleteUInt(bytes32 record);

  mapping(bytes32 => string) String;

  function getString(bytes32 record) 
    constant 
    returns (string);

  function setString(bytes32 record, string value);

  function deleteString(bytes32 record);

  mapping(bytes32 => address) Address;

  function getAddress(bytes32 record) 
    constant 
    returns (address);

  function setAddress(bytes32 record, address value);

  function deleteAddress(bytes32 record);

  mapping(bytes32 => bytes) Bytes;

  function getBytes(bytes32 record) 
    constant 
    returns (bytes);

  function setBytes(bytes32 record, bytes value);

  function deleteBytes(bytes32 record);

  mapping(bytes32 => bytes32) Bytes32;

  function getBytes32(bytes32 record) 
    constant 
    returns (bytes32);

  function setBytes32(bytes32 record, bytes32 value);

  function deleteBytes32(bytes32 record);

  mapping(bytes32 => bool) Boolean;

  function getBoolean(bytes32 record) 
    constant 
    returns (bool);

  function setBoolean(bytes32 record, bool value);

  function deleteBoolean(bytes32 record);

  mapping(bytes32 => int) Int;

  function getInt(bytes32 record) 
    constant 
    returns (int);

  function setInt(bytes32 record, int value);

  function deleteInt(bytes32 record);
}
