// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SignatureTest is Test, EIP712 {

    struct Message {
        string content;
    }

    bytes32 private constant MESSAGE_TYPE_HASH = keccak256("Message(string content)");
    address private user;
    uint256 private privateKey;

    constructor() EIP712("Test", "1.0.0") {}

    function setUp() external {
        (user, privateKey) = makeAddrAndKey("user");
    }

    function testSignAndVerify() public view {
        // Create EIP712 digest
        bytes32 messageHash = keccak256(
            abi.encode(
                MESSAGE_TYPE_HASH, 
                keccak256(abi.encode(Message({ content: "hello" })))
            )
        );
        bytes32 digest = _hashTypedDataV4(messageHash);
        // Create ECDSA signature, signature = abi.encodePacked(r, s, v), 65 bytes
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        // Verify signature
        (address actualSigner, , ) = ECDSA.tryRecover(digest, v, r, s);
        console.log("Actual signer:", actualSigner);
        // Check
        assertEq(actualSigner, user);
    }
    
}