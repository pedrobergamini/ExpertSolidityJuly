pragma solidity ^0.8.4;

contract Add {
    function addAssembly(uint x, uint y) public pure returns (uint) {
        assembly {
            mstore(0x00, add(x, y))
        }
        // But can be written to memory in one block
        // and retrieved in another
        assembly {
            return(0x00, 32)
        }
    }

    function addSolidity(uint x, uint y) public pure returns (uint) {
        return x + y;
    }
}
