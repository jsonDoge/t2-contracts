//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Plot is ERC721 {
    // this is farm contract
    address _admin;
    uint256 private _cap;
    uint256 private _totalSupply;

    // tokenId [0-999999] contains the coordinate information: 
    // X row going along the top starts at 0 ends 999
    // Y row going along the left side starts at 0 ends 999000

    constructor(
        string memory name,
        string memory symbol,
        address admin,
        uint256 cap_
    ) ERC721(name, symbol) {
         require(cap_ > 0, "Cap is 0");

        _admin = admin;
        _cap = cap_;
    }

    modifier onlyAdmin() {
        require(_admin == msg.sender, "ONLY_ADMIN");
        _;
    }

    function mint(address to, uint256 tokenId) public onlyAdmin returns (bool) {
        require(_totalSupply + 1 < _cap, "PLOT_CAP_EXCEEDED");
        require(tokenId < _cap, "PLOT_INVALID_ID");
        require(!exists(tokenId), "PLOT_ALREADY_MINTED");

        _safeMint(to, tokenId);

        _totalSupply += 1;
        return true;
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
