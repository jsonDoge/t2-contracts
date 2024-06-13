//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../Utils.sol";

/**
 * @dev Test contract for Utils library
 */
contract UtilsTest {
    constructor() {}

    // TODO: go into more details about this method and why it works with library contracts
    fallback () external payable {
        address _impl = address(Utils);
        require(_impl != address(0), "Library address not set");

        assembly {
            // Load the calldata into memory
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())

            // Delegate the call to the library contract
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)

            // Retrieve the size of the returned data
            let size := returndatasize()

            // Copy the returned data to memory
            returndatacopy(ptr, 0, size)

            // Handle the return or revert
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}
