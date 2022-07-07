// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTContract is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public NFTItemTracker;

    constructor() ERC721("DAPP", "DAPP") {}

    // // ///////////////////////////////////////////////////////////////////////////////////// MINT

    function mintNewNFT(string memory _URI, address _mintTo)
        external
        onlyOwner
        returns (bool)
    {
        NFTItemTracker.increment();
        uint256 _newID = NFTItemTracker.current();

        _mint(_mintTo, _newID);
        _setTokenURI(_newID, _URI);

        return true;
    }
}
