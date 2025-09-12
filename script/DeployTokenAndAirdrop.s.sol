// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {DeerToken} from "../src/DeerToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {AirdropMerkleHelper} from "./helper/AirdropMerkleHelper.sol";

contract DeployTokenAndAirdrop is Script {

    struct Airdrop {
        address account;
        uint256 amount;
    }

    uint256 private constant INITIAL_SUPPLY = 10000 ether;

    function run() external {
        deploy();
    }

    function deploy() public returns (DeerToken, MerkleAirdrop) {
        AirdropMerkleHelper airdropMerkleHelper = new AirdropMerkleHelper();
        bytes32 merkleRoot = airdropMerkleHelper.makeAirdropListMerkleTreeByConfig();
        return deploy(merkleRoot);
    }

    function deploy(bytes32 merkleRoot) public returns (DeerToken, MerkleAirdrop) {
        vm.startBroadcast();
        DeerToken token = deployDeerToken();
        MerkleAirdrop merkleAirdrop = deployMerkleAirdrop(IERC20(address(token)), merkleRoot);
        token.mint(address(merkleAirdrop), INITIAL_SUPPLY);
        vm.stopBroadcast();
        return (token, merkleAirdrop);
    }

    function deployDeerToken() private returns (DeerToken) {
        return new DeerToken();
    }

    function deployMerkleAirdrop(IERC20 token, bytes32 merkleRoot) private returns (MerkleAirdrop) {
        return new MerkleAirdrop(token, merkleRoot);
    }

}