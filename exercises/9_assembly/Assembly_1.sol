pragma solidity ^0.8.4;

contract Intro {
    function intro() public pure returns (uint16) {
        uint256 mol = 420;

        // Yul assembly magic happens within assembly{} section
        assembly {
            mstore(0x00, mol)
            return(0x00, 32)
        }
    }
}
