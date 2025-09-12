// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DeerToken} from "../../src/DeerToken.sol";
import {MerkleAirdrop} from "../../src/MerkleAirdrop.sol";
import {AirdropMerkleHelper} from "../../script/helper/AirdropMerkleHelper.sol";
import {DeployTokenAndAirdrop} from "../../script/DeployTokenAndAirdrop.s.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {Vm} from "forge-std/Vm.sol";

contract MerkleAirdropTest is Test {

    event MerkleAirdrop__Claim(address indexed account, uint256 indexed amount);

    MerkleAirdrop private merkleAirdrop;
    DeerToken private deerToken;
    AirdropMerkleHelper private airdropMerkleHelper;
    Vm.Wallet private userWallet;
    AirdropMerkleHelper.Airdrop private airdrop;
    uint256 private airdropPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;


    function setUp() external {
        DeployTokenAndAirdrop deployer = new DeployTokenAndAirdrop();
        (deerToken, merkleAirdrop) = deployer.deploy();
        airdropMerkleHelper = new AirdropMerkleHelper();
        userWallet = vm.createWallet("user");
        AirdropMerkleHelper.Airdrop[] memory airdropList = airdropMerkleHelper.getAirdropListFromConfig();
        airdrop = airdropList[0];
    }

    function test_RevertWhen_ClaimWithWrongSignature() public {
        bytes32 digest = merkleAirdrop.getEIP712Digest(airdrop.account, airdrop.amount);
        // Sign message using wrong account 
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userWallet, digest);
        // Create merkle tree proofs
        bytes32[] memory proofs = airdropMerkleHelper.getProof(airdrop.account, airdrop.amount);
        // Claim
        vm.expectRevert(abi.encodeWithSelector(MerkleAirdrop.MerkleAirdrop__AccountAndSignatureNotMatch.selector, userWallet.addr));
        merkleAirdrop.claim(airdrop.account, airdrop.amount, proofs, v, r, s);
    }

    function test_RevertWhen_RandomUserTryToClaim() public {
        AirdropMerkleHelper.Airdrop memory randomUserAirdrop = AirdropMerkleHelper.Airdrop({
            account: userWallet.addr,
            amount: 10 ether
        });
        bytes32 digest = merkleAirdrop.getEIP712Digest(randomUserAirdrop.account, randomUserAirdrop.amount);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userWallet, digest);
        // Create merkle tree proofs
        bytes32[] memory proofs = airdropMerkleHelper.getProof(randomUserAirdrop.account, randomUserAirdrop.amount);
        // Claim
        vm.expectRevert(abi.encodeWithSelector(MerkleAirdrop.MerkleAirdrop__InvalidProof.selector, userWallet.addr, randomUserAirdrop.amount));
        merkleAirdrop.claim(randomUserAirdrop.account, randomUserAirdrop.amount, proofs, v, r, s);
    }

    function test_RevertWhen_UserHasClaimed() public {
        bytes32 digest = merkleAirdrop.getEIP712Digest(airdrop.account, airdrop.amount);
        // The private key of account 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(airdropPrivateKey, digest);
        // Create merkle tree proofs
        bytes32[] memory proofs = airdropMerkleHelper.getProof(airdrop.account, airdrop.amount);
        // Claim
        merkleAirdrop.claim(airdrop.account, airdrop.amount, proofs, v, r, s);
        vm.expectRevert(abi.encodeWithSelector(MerkleAirdrop.MerkleAirdrop__AccountHasClaimed.selector, airdrop.account));
        merkleAirdrop.claim(airdrop.account, airdrop.amount, proofs, v, r, s);
    }

    function test_RevertWhen_ClaimWrongAmountOfToken() public {
        uint256 claimAmount = airdrop.amount + 1 ether;
        bytes32 digest = merkleAirdrop.getEIP712Digest(airdrop.account, claimAmount);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(airdropPrivateKey, digest);
        // Create merkle tree proofs
        bytes32[] memory proofs = airdropMerkleHelper.getProof(airdrop.account, claimAmount);
        // Claim
        vm.expectRevert(abi.encodeWithSelector(MerkleAirdrop.MerkleAirdrop__InvalidProof.selector, airdrop.account, claimAmount));
        merkleAirdrop.claim(airdrop.account, claimAmount, proofs, v, r, s);
    }

    function testClaim() public {
        // Starting balance
        uint256 startingContractBalance = deerToken.balanceOf(address(merkleAirdrop));
        uint256 startingAccountBalance = deerToken.balanceOf(airdrop.account);
        // EIP-712 digest
        bytes32 digest = merkleAirdrop.getEIP712Digest(airdrop.account, airdrop.amount);
        // The private key of account 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(airdropPrivateKey, digest);
        // Create merkle tree proofs
        bytes32[] memory proofs = airdropMerkleHelper.getProof(airdrop.account, airdrop.amount);
        // Event
        vm.expectEmit(true, true, true, false);
        emit MerkleAirdrop__Claim(airdrop.account, airdrop.amount);
        // Claim
        merkleAirdrop.claim(airdrop.account, airdrop.amount, proofs, v, r, s);
        // Check balance
        assertEq(deerToken.balanceOf(address(merkleAirdrop)), startingContractBalance - airdrop.amount);
        assertEq(deerToken.balanceOf(airdrop.account), startingAccountBalance + airdrop.amount);
    }

}