// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleAirdrop is EIP712, Ownable {

    using SafeERC20 for IERC20;

    error MerkleAirdrop__AccountAndSignatureNotMatch(address account);
    error MerkleAirdrop__InvalidProof(address account, uint256 amount);
    error MerkleAirdrop__AccountHasClaimed(address account);

    event MerkleAirdrop__Claim(address indexed account, uint256 indexed amount);

    struct TokenClaim {
        address account;
        uint256 amount;
    }

    bytes32 private constant TOKEN_CLAIM_TYPE_HASH = keccak256("TokenClaim(address account,uint256 amount)"); 
    string private constant APPLICATION_NAME = "MerkleAirdrop";
    string private constant APPLICATION_VERSION = "1.0.0";

    IERC20 private immutable i_token;
    mapping(address account => bool claimed) private s_claimed;
    bytes32 private s_merkleRoot;

    constructor(
        IERC20 token, 
        bytes32 merkleRoot
    ) 
        EIP712(APPLICATION_NAME, APPLICATION_VERSION) 
        Ownable(msg.sender)
    {
        i_token = token;
        s_merkleRoot = merkleRoot;
    }

    function claim(
        address account, 
        uint256 amount, 
        bytes32[] memory merkleProofs, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external {
        // Check if `account` has claimed
        if (s_claimed[account]) {
            revert MerkleAirdrop__AccountHasClaimed(account);
        }
        // Verify signature
        _verifySignature(account, amount, v, r, s);
        // Verify if `account` is in the airdrop list
        _verifyAccount(account, amount, merkleProofs);
        s_claimed[account] = true;
        emit MerkleAirdrop__Claim(account, amount);
        // Transfer token to `account`
        i_token.safeTransfer(account, amount);
    }

    function setMerkleRoot(bytes32 newRoot) public onlyOwner {
        s_merkleRoot = newRoot;
    }

    function _verifyAccount(address account, uint256 amount, bytes32[] memory merkleProofs) private view {
        bytes32 leaf = _createMerkleLeaf(account, amount);
        bool result = MerkleProof.verify(merkleProofs, s_merkleRoot, leaf);
        if (!result) {
            revert MerkleAirdrop__InvalidProof(account, amount);
        }
    }

    function _createMerkleLeaf(address account, uint256 amount) private pure returns (bytes32) {
        // Double hash
        return keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
    }

    function _verifySignature(address account, uint256 amount, uint8 v, bytes32 r, bytes32 s) private view {
        bytes32 digest = getEIP712Digest(account, amount);
        (address actualSigner, , ) = ECDSA.tryRecover(digest, v, r, s);
        if (account != actualSigner) {
            revert MerkleAirdrop__AccountAndSignatureNotMatch(actualSigner);
        }
    }

    function getEIP712Digest(address account, uint256 amount) public view returns (bytes32) {
        // Create struct instance
        TokenClaim memory tokenClaim = TokenClaim({
            account: account,
            amount: amount
        });
        // Create EIP712 digest
        bytes32 structHash = keccak256(abi.encode(TOKEN_CLAIM_TYPE_HASH, keccak256(abi.encode(tokenClaim))));
        return _hashTypedDataV4(structHash);
    }

    function getMerkleRoot() public view returns (bytes32) {
        return s_merkleRoot;
    }

    function getAirdropToken() public view returns (address) {
        return address(i_token);
    }

    function getApplicationName() public pure returns (string memory) {
        return APPLICATION_NAME;
    }

    function getApplicationVersion() public pure returns (string memory) {
        return APPLICATION_VERSION;
    }

}