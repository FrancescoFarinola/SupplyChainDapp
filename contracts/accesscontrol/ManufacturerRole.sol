pragma solidity ^0.8.13;

// Import the library 'Roles'
import "./Roles.sol";

// Define a contract 'ManufacturerRole' to manage this role - add, remove, check
contract ManufacturerRole {

  using Roles for Roles.Role;

  // Define 2 events, one for Adding, and other for Removing
  event ManufacturerAdded(address indexed account);
  event ManufacturerRemoved(address indexed account);
  // Define a struct 'manufactures' by inheriting from 'Roles' library, struct Role
  Roles.Role private manufactures;

  // In the constructor make the address that deploys this contract the 1st Manufacturer
  constructor() {
    _addManufacturer(msg.sender);
  }

  // Define a modifier that checks to see if msg.sender has the appropriate role
  modifier onlyManufacturer() {
    require(manufactures.has(msg.sender), "This account has no Manufacturer Role");
    _;
  }

  // Define a function 'isManufacturer' to check this role
  function isManufacturer(address account) public view returns (bool) {
    return manufactures.has(account);
  }

  // Define a function 'addManufacturer' that adds this role
  function addManufacturer(address account) public onlyManufacturer {
    _addManufacturer(account);
  }

  // Define a function 'renounceManufacturer' to renounce this role
  function renounceManufacturer() public {
    _removeManufacturer(msg.sender);
  }

  // Define an internal function '_addManufacturer' to add this role, called by 'addManufacturer'
  function _addManufacturer(address account) internal {
    manufactures.add(account);
    emit ManufacturerAdded(account);
  }

  // Define an internal function '_removeManufacturer' to remove this role, called by 'removeManufacturer'
  function _removeManufacturer(address account) internal {
    manufactures.remove(account);
    emit ManufacturerRemoved(account);
  }
}