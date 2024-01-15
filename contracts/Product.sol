//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev Extension of {ERC20} that adds a set of accounts with the {MinterRole},
 * which have permission to mint (create) new tokens as they see fit.
 *
 * At construction, the deployer of the contract is the only minter.
 */

contract Product is ERC20 {

    // _admin is the farm contract
    address _admin;
    uint256 _yield;

    constructor(
        string memory name,
        string memory symbol,
        address admin,
        uint256 yield
    ) ERC20(name, symbol) {
        _admin = admin;
        _yield = yield;
    }

    modifier onlyAdmin() {
        require(_admin == msg.sender, "ONLY_ADMIN");
        _;
    }

    function mint(address account, uint256 quantity) public onlyAdmin returns (bool) {
        _mint(account, quantity);
        return true;
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }

    function getYield() public view returns (uint256) {
      return _yield;
    }
}
