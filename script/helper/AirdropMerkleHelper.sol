// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DeerToken} from "../../src/DeerToken.sol";
import {MerkleAirdrop} from "../../src/MerkleAirdrop.sol";
import {Merkle} from "murky/src/Merkle.sol";

contract AirdropMerkleHelper is Script {

    struct Airdrop {
        address account;
        uint256 amount;
    }

    string private constant CONFIG_FILE_PATH = "script/config/airdropList.json";
    Merkle private merkle;

    constructor() {
        merkle = new Merkle();
    }

    function makeAirdropListMerkleTreeByConfig() public view returns (bytes32) {
        return getMerkleRoot(getHashedAirdropListFromConfig());
    }

    function getMerkleRoot(bytes32[] memory airdropList) public view returns (bytes32) {
        return merkle.getRoot(airdropList);
    }

    function getAirdropListFromConfig() public view returns (Airdrop[] memory) {
        string memory configJson = vm.readFile(CONFIG_FILE_PATH);
        return abi.decode(vm.parseJson(configJson), (Airdrop[]));
    }

    function getHashedAirdropList(Airdrop[] memory airdrops) public pure returns (bytes32[] memory) {
        bytes32[] memory airdropHashArr = new bytes32[](airdrops.length);
        for (uint256 i = 0; i < airdrops.length; i++) {
            bytes32 airdropHash = getLeaf(airdrops[i].account, airdrops[i].amount);
            airdropHashArr[i] = airdropHash;
        }
        return airdropHashArr;
    }

    function getHashedAirdropListFromConfig() public view returns (bytes32[] memory) {
        return getHashedAirdropList(getAirdropListFromConfig());
    }

    function getLeaf(address account, uint256 amount) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
    }

    function getProof(address account, uint256 amount) public view returns (bytes32[] memory) {
        bytes32 leaf = getLeaf(account, amount);
        bytes32[] memory hashedAirdropList = getHashedAirdropListFromConfig();
        for (uint256 i = 0; i < hashedAirdropList.length; i++) {
            if (leaf == hashedAirdropList[i]) {
                return merkle.getProof(hashedAirdropList, i);
            }
        }
        return new bytes32[](0);
    }

    function getClaimAmount(address account) public view returns (uint256) {
        Airdrop[] memory airdropList = getAirdropListFromConfig();
        for (uint256 i = 0; i < airdropList.length; i++) {
            if (airdropList[i].account == account) {
                return airdropList[i].amount;
            }
        }
        return 0;
    }
}