// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {ERC721Checkpointable} from "./base/ERC721Checkpointable.sol";
import {ERC721} from "./base/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTContract is ERC721Checkpointable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public NFTItemTracker;

    uint256 public maxSupply = 10;

    constructor() ERC721("DAPP", "DAPP") {}

    // // ///////////////////////////////////////////////////////////////////////////////////// MINT

    function mintNFT(address _mintTo, uint256 _newID)
        external
        onlyOwner
        returns (bool)
    {
        _mint(_mintTo, _newID);
        return true;
    }

    function transferNFTToWinner(address _mintTo)
        external
        onlyOwner
        returns (bool)
    {
        NFTItemTracker.increment();
        uint256 _newID = NFTItemTracker.current();

        require(_newID <= maxSupply, " Max Supply reached !");
        _transfer(owner(), _mintTo, _newID);

        return true;
    }
}
