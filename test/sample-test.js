const { ethers } = require("hardhat");
const { expect } = require("chai");

const ImageData = require("./utils/imageData.json");

describe("Test Deploy", async function () {
  let NFTContract;
  let MasterContract;
  let DescriptorStorageContract;

  let TX;
  let currentAuction;

  let addr1;
  let addr2;
  let addr3;

  beforeEach(async function () {
    [, addr1, addr2, addr3] = await ethers.getSigners();

    // DEPLOYMENT NFTContract
    const NFT = await ethers.getContractFactory("NFTContract");
    NFTContract = await NFT.deploy();
    await NFTContract.deployed();

    // DEPLOYMENT MY CONTRACTS
    const Master = await ethers.getContractFactory("Master");
    MasterContract = await Master.deploy();
    await MasterContract.deployed();

    const DescriptorStorage = await ethers.getContractFactory(
      "DescriptorStorage"
    );
    DescriptorStorageContract = await DescriptorStorage.deploy();
    await DescriptorStorageContract.deployed();

    await MasterContract.setNounsDescriptor(DescriptorStorageContract.address);
    await MasterContract.setNFTContract(NFTContract.address);

    // SETUP

    const { bgcolors, palette, images } = ImageData;
    const { bodies, accessories, heads, glasses } = images;

    await DescriptorStorageContract.addManyBackgrounds(bgcolors);
    await DescriptorStorageContract.addManyColorsToPalette(0, palette);
    await DescriptorStorageContract.addManyBodies(
      bodies.map(({ data }) => data)
    );

    const accessoriesArray = [];
    for (let i = 0; i < accessories.length; i += 10) {
      accessoriesArray.push(accessories.slice(i, i + 10));
    }
    accessoriesArray.map(
      async (item) =>
        await DescriptorStorageContract.addManyAccessories(
          item.map(({ data }) => data)
        )
    );

    const headsArray = [];
    for (let i = 0; i < heads.length; i += 10) {
      headsArray.push(heads.slice(i, i + 10));
    }
    headsArray.map(
      async (item) =>
        await DescriptorStorageContract.addManyHeads(
          item.map(({ data }) => data)
        )
    );

    DescriptorStorageContract.addManyGlasses(glasses.map(({ data }) => data));

    await NFTContract.transferOwnership(MasterContract.address);
    await DescriptorStorageContract.transferOwnership(MasterContract.address);
  });

  describe("Start Project Once !", () => {
    it("", async () => {
      TX = await MasterContract.startGame();
      await TX.wait();

      const currentAuction = await MasterContract.getCurrentAuctionDetails();

      // check currentAuction auction to be equal 1
      expect(currentAuction[0].toString()).to.equal("1");
      // check currentAuction last amount to be equal 0
      expect(currentAuction[1].toString()).to.equal("0");
      // check currentAuction bidder to be equal address 0
      expect(currentAuction[4].toString()).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      // check currentAuction is finished to be equal false
      expect(currentAuction[5].toString()).to.equal("false");

      // and we will get revert because we can't again use  startGame function to start any auction
      await expect(MasterContract.startGame()).to.be.revertedWith(
        "Already started !"
      );
    });
  });

  describe("Bid On Current Auction , check revert options ", () => {
    beforeEach(async function () {
      TX = await MasterContract.startGame();
      await TX.wait();
    });
    it("", async () => {
      const currentAuctionID = 1;

      // make bid on current running auction
      TX = await MasterContract.connect(addr1).createBid(currentAuctionID, {
        value: ethers.utils.parseEther("1"),
      });
      await TX.wait(1);

      // now check auction details with ID #1
      currentAuction = await MasterContract.getCurrentAuctionDetails();

      // check currentAuction auction to be equal 1
      expect(currentAuction[0].toString()).to.equal("1");
      // check currentAuction last amount to be equal 1 ether
      expect(currentAuction[1]).to.equal(ethers.utils.parseEther("1"));
      // check currentAuction bidder to be equal address addre1
      expect(currentAuction[4]).to.equal(addr1.address);
      // check currentAuction is finished to be equal false
      expect(currentAuction[5].toString()).to.equal("false");

      // now check if we get revert !
      await expect(
        MasterContract.connect(addr2).createBid(currentAuctionID, {
          value: ethers.utils.parseEther("0.5"),
        })
      ).to.be.revertedWith(
        "Must send more than last bid by minBidIncrementPercentage amount"
      );

      await expect(
        MasterContract.connect(addr2).createBid(2, {
          value: ethers.utils.parseEther("1"),
        })
      ).to.be.revertedWith("Noun not up for auction");

      // addr3 make more bid !
      TX = await MasterContract.connect(addr3).createBid(currentAuctionID, {
        value: ethers.utils.parseEther("2"),
      });
      await TX.wait(1);

      // now check auction details with ID #1
      currentAuction = await MasterContract.getCurrentAuctionDetails();

      // check currentAuction auction to be equal 1
      expect(currentAuction[0].toString()).to.equal("1");
      // check currentAuction last amount to be equal 1 ether
      expect(currentAuction[1]).to.equal(ethers.utils.parseEther("2"));
      // check currentAuction bidder to be equal address addre1
      expect(currentAuction[4]).to.equal(addr3.address);
      // check currentAuction is finished to be equal false
      expect(currentAuction[5].toString()).to.equal("false");

      // now mine new blocks to get auction end time ! and current auction will get expire !
      for (let i = 0; i < 10; i++) {
        ethers.provider.send("evm_mine");
      }

      await expect(
        MasterContract.connect(addr2).createBid(1, {
          value: ethers.utils.parseEther("1"),
        })
      ).to.be.revertedWith("Auction expired");
    });
  });

  describe("Bid On Current Auction , Mint NFT For Winner, Start New Auction", () => {
    beforeEach(async function () {
      TX = await MasterContract.startGame();
      await TX.wait();
    });
    it("", async () => {
      const currentAuctionID = 1;

      // make bid on current running auction
      TX = await MasterContract.connect(addr1).createBid(currentAuctionID, {
        value: ethers.utils.parseEther("1"),
      });
      await TX.wait(1);

      // now mine new blocks to get auction end time ! and current auction will get expire !
      for (let i = 0; i < 10; i++) {
        ethers.provider.send("evm_mine");
      }

      // finish auction
      TX = await MasterContract.finishCurrentAndCreateNewAuction();
      await TX.wait(1);

      // now check auction details with ID #2 because master contract created new auction
      currentAuction = await MasterContract.getCurrentAuctionDetails();

      // check currentAuction auction to be equal 1
      expect(currentAuction[0].toString()).to.equal("2");
      // check currentAuction last amount to be equal 1 ether
      expect(currentAuction[1]).to.equal(ethers.utils.parseEther("0"));
      // check currentAuction bidder to be equal address addre1
      expect(currentAuction[4]).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      // check currentAuction is finished to be equal false
      expect(currentAuction[5].toString()).to.equal("false");

      // we minted new NFT with ID 1 for winner of auction with ID 1 ! let's check it
      expect(await NFTContract.ownerOf(1)).to.equal(addr1.address);
    });
  });
});
