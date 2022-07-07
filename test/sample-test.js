const { ethers } = require("hardhat");
const { expect } = require("chai");

const ImageData = require("./utils/imageData.json");

describe("Test Deploy", async function () {
  it("Test Pro", async function () {
    const [, addr1] = await ethers.getSigners();

    // DEPLOYMENT NFTContract
    const NFT = await ethers.getContractFactory("NFTContract");
    const NFTContract = await NFT.deploy();
    await NFTContract.deployed();

    // DEPLOYMENT MY CONTRACTS
    const Master = await ethers.getContractFactory("Master");
    const MasterContract = await Master.deploy();
    await MasterContract.deployed();

    const DescriptorStorage = await ethers.getContractFactory(
      "DescriptorStorage"
    );
    const DescriptorStorageContract = await DescriptorStorage.deploy();
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

    // TEST DATA
    const nounId = 1;

    const seed = await MasterContract.generateSeed(nounId);
    console.log(seed.toString());

    const svg = await MasterContract.generateSVGImage(seed);
    await svg.wait(1);

    const createdSVG = await MasterContract.LastCreatedSVG();
    console.log(createdSVG.toString());

    const newNFTID = await MasterContract.mintNewNFT(addr1.address);
    await newNFTID.wait(1);

    expect(await NFTContract.tokenURI(1)).to.equal(createdSVG.toString());
    expect(await NFTContract.ownerOf(1)).to.equal(addr1.address);
  });
});
