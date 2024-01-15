//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev A ERC20 contract that anyone can mint. Will play as a placeholder for later stablecoin
 */
contract ERC20Mintable is ERC20 {

    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {}

    function mint(address account, uint256 quantity) public returns (bool) {
        require(quantity <= 100, "DONT_BE_GREEDY");

        _mint(account, quantity);
        return true;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
