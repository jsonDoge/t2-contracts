//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// used for production combination result

contract Dish is ERC721 {
    // this is farm contract
    address _admin;
    uint256 _lastId = 0;

    constructor(
        string memory name,
        string memory symbol,
        address admin
    ) ERC721(name, symbol) {
        _admin = admin;
    }

    modifier onlyAdmin() {
        require(_admin == msg.sender, "ONLY_ADMIN");
        _;
    }

    function mintNext(address to) public onlyAdmin returns (bool) {
        _lastId++;
        _mint(to, _lastId);
        return true;
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
