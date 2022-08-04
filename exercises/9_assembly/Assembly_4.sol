pragma solidity ^0.8.4;

contract Scope {
    uint public count = 10;

    function increment(uint numb) public {
        // Modify state of the count from within
        // the assembly segment
        assembly {
            sstore(0x00, add(sload(0x00), numb))
        }
    }
}
