// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {INounsSeeder} from "./interfaces/INounsSeeder.sol";
import {MultiPartRLEToSVG} from "./libs/MultiPartRLEToSVG.sol";

import {Base64} from "base64-sol/base64.sol";

import "./DescriptorStorage.sol";
import "./NFTContract.sol";

contract Master is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public IDTracker;

    DescriptorStorage DescriptorStorageContract;
    NFTContract NFTToken;

    struct Seed {
        uint48 background;
        uint48 body;
        uint48 accessory;
        uint48 head;
        uint48 glasses;
    }

    string public LastCreatedSVG;

    // // /////////////////////////////////////////////////////////////// SET ADDRESS

    function setNounsDescriptor(address _DescriptorStorage)
        external
        onlyOwner
        returns (bool)
    {
        DescriptorStorageContract = DescriptorStorage(_DescriptorStorage);
        return true;
    }

    function setNFTContract(address _NFTContract)
        external
        onlyOwner
        returns (bool)
    {
        NFTToken = NFTContract(_NFTContract);
        return true;
    }

    // // /////////////////////////////////////////////////////////////// SEED FUNCTIONS

    function generateSeed(uint256 nounId)
        external
        view
        onlyOwner
        returns (Seed memory)
    {
        uint256 pseudorandomness = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), nounId))
        );

        uint256 backgroundCount = DescriptorStorageContract.backgroundCount();
        uint256 bodyCount = DescriptorStorageContract.bodyCount();
        uint256 accessoryCount = DescriptorStorageContract.accessoryCount();
        uint256 headCount = DescriptorStorageContract.headCount();
        uint256 glassesCount = DescriptorStorageContract.glassesCount();

        return
            Seed({
                background: uint48(uint48(pseudorandomness) % backgroundCount),
                body: uint48(uint48(pseudorandomness >> 48) % bodyCount),
                accessory: uint48(
                    uint48(pseudorandomness >> 96) % accessoryCount
                ),
                head: uint48(uint48(pseudorandomness >> 144) % headCount),
                glasses: uint48(uint48(pseudorandomness >> 192) % glassesCount)
            });
    }

    // // /////////////////////////////////////////////////////////////// SVG IMAGE FUNCTIONS

    function generateSVGImage(INounsSeeder.Seed memory seed)
        external
        onlyOwner
        returns (string memory)
    {
        LastCreatedSVG = DescriptorStorageContract.generateSVGImage(seed);
        return LastCreatedSVG;
    }

    // // /////////////////////////////////////////////////////////////// MINT NEW NFT FOR SOLD SVG
    function mintNewNFT(address _mintTo) external onlyOwner {
        NFTToken.mintNewNFT(LastCreatedSVG, _mintTo);
    }
}
