//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev Extension of {ERC20} that adds a set of accounts with the {MinterRole},
 * which have permission to mint (create) new tokens as they see fit.
 *
 * At construction, the deployer of the contract is the only minter.
 */
contract Seed is ERC20 {

    // for seeds and products this is farm contract
    address _admin;
    uint256 _growthDuration; // in blocks
    uint256 _minWater; // minimum water to harvest
    uint8 _growthSeasons; // bitWise 0 0 0 0 each bit represents a season, has to be 0 < x < 16

    constructor(
        string memory name,
        string memory symbol,
        address admin,
        uint256 growthDuration,
        uint8 growthSeasons,
        uint256 minWater
    ) ERC20(name, symbol) {
        _admin = admin;
        _growthDuration = growthDuration;
        _growthSeasons = growthSeasons;
        _minWater = minWater;
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

    function getGrowthDuration() public view returns (uint256) {
      return _growthDuration;
    }

    function getMinWater() public view returns (uint256) {
      return _minWater;
    }

    function getGrowthSeasons() public view returns (uint8) {
      return _growthSeasons;
    }
}
