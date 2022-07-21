// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {INounsSeeder} from "./interfaces/Seeder.sol";
import {MultiPartRLEToSVG} from "./libs/MultiPartRLEToSVG.sol";

import {Base64} from "base64-sol/base64.sol";

import "./DescriptorStorage.sol";
import "./NFTContract.sol";

contract Master is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public auctionIDTracker;

    DescriptorStorage DescriptorStorageContract;
    NFTContract NFTToken;

    struct Seed {
        uint48 background;
        uint48 body;
        uint48 accessory;
        uint48 head;
        uint48 glasses;
    }

    struct Auction {
        uint256 auctionID;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        address payable bidder;
        bool finished;
    }
    Auction public auction;

    string public LastCreatedSVG;
    uint256 public duration = 10;

    bool started;

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
        private
        view
        returns (INounsSeeder.Seed memory)
    {
        uint256 pseudorandomness = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), nounId))
        );

        uint256 backgroundCount = DescriptorStorageContract.backgroundCount();
        uint256 bodyCount = DescriptorStorageContract.bodyCount();
        uint256 accessoryCount = DescriptorStorageContract.accessoryCount();
        uint256 headCount = DescriptorStorageContract.headCount();
        uint256 glassesCount = DescriptorStorageContract.glassesCount();

        INounsSeeder.Seed memory _newSeed = INounsSeeder.Seed({
            background: uint48(uint48(pseudorandomness) % backgroundCount),
            body: uint48(uint48(pseudorandomness >> 48) % bodyCount),
            accessory: uint48(uint48(pseudorandomness >> 96) % accessoryCount),
            head: uint48(uint48(pseudorandomness >> 144) % headCount),
            glasses: uint48(uint48(pseudorandomness >> 192) % glassesCount)
        });

        return _newSeed;
    }

    // // /////////////////////////////////////////////////////////////// SVG IMAGE FUNCTIONS

    function generateSVGImage(INounsSeeder.Seed memory seed)
        private
        returns (string memory)
    {
        LastCreatedSVG = DescriptorStorageContract.generateSVGImage(seed);
        return LastCreatedSVG;
    }

    // // /////////////////////////////////////////////////////////////// AUCTION

    function finishCurrentAndCreateNewAuction() external {
        _finishCurrentAuction();
        _createAuction();
    }

    function startGame() external onlyOwner {
        require(started == false, "Already started !");
        _createAuction();
        started = true;
    }

    function _createAuction() private {
        auctionIDTracker.increment();
        uint256 _auctionIDTracker = auctionIDTracker.current();

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        INounsSeeder.Seed memory _newSeed = generateSeed(_auctionIDTracker);
        generateSVGImage(_newSeed);

        auction = Auction({
            auctionID: _auctionIDTracker,
            amount: 0,
            startTime: startTime,
            endTime: endTime,
            bidder: payable(0),
            finished: false
        });
    }

    function _finishCurrentAuction() private {
        Auction memory _auction = auction;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.finished, "Auction has already been settled");
        require(
            block.timestamp >= _auction.endTime,
            "Auction hasn't completed"
        );

        auction.finished = true;

        if (_auction.bidder != address(0)) {
            NFTToken.transferNFTToWinner(_auction.bidder);
        }
    }

    // // /////////////////////////////////////////////////////////////// BID ON AUCTION

    function createBid(uint256 _auctionIDTracker) external payable {
        Auction memory _auction = auction;

        require(
            _auction.auctionID == _auctionIDTracker,
            "Noun not up for auction"
        );
        require(block.timestamp < _auction.endTime, "Auction expired");
        require(
            msg.value >= _auction.amount,
            "Must send more than last bid by minBidIncrementPercentage amount"
        );

        address payable lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0)) {
            lastBidder.transfer(_auction.amount);
        }

        auction.amount = msg.value;
        auction.bidder = payable(msg.sender);
    }

    // // /////////////////////////////////////////////////////////////// GET CURRENT AUCTION
    function getCurrentAuctionDetails() external view returns (Auction memory) {
        return auction;
    }

    // // /////////////////////////////////////////////////////////////// DAO
}
