const { ethers } = require("hardhat");

const ImageData = require("./utils/imageData.json");

describe("Test Deploy", function () {
  it("", async function () {
    // DEPLOYMENT
    const NFTDescriptor = await ethers.getContractFactory("NFTDescriptor");
    const NFTDescriptorContract = await NFTDescriptor.deploy();
    await NFTDescriptorContract.deployed();

    // DEPLOYMENT
    const NounsDescriptor = await ethers.getContractFactory("NounsDescriptor", {
      libraries: {
        "contracts/libs/NFTDescriptor.sol:NFTDescriptor":
          NFTDescriptorContract.address,
      },
    });
    const NounsDescriptorContract = await NounsDescriptor.deploy();
    await NounsDescriptorContract.deployed();

    // DEPLOYMENT
    const NounsSeeder = await ethers.getContractFactory("NounsSeeder");
    const NounsSeederContract = await NounsSeeder.deploy();
    await NounsSeederContract.deployed();

    // SETUP

    const { bgcolors, palette, images } = ImageData;
    const { bodies, accessories, heads, glasses } = images;

    await NounsDescriptorContract.addManyBackgrounds(bgcolors);
    await NounsDescriptorContract.addManyColorsToPalette(0, palette);
    await NounsDescriptorContract.addManyBodies(bodies.map(({ data }) => data));

    const accessoriesArray = [];
    for (let i = 0; i < accessories.length; i += 10) {
      accessoriesArray.push(accessories.slice(i, i + 10));
    }
    accessoriesArray.map(
      async (item) =>
        await NounsDescriptorContract.addManyAccessories(
          item.map(({ data }) => data)
        )
    );

    const headsArray = [];
    for (let i = 0; i < heads.length; i += 10) {
      headsArray.push(heads.slice(i, i + 10));
    }
    headsArray.map(
      async (item) =>
        await NounsDescriptorContract.addManyHeads(item.map(({ data }) => data))
    );

    NounsDescriptorContract.addManyGlasses(glasses.map(({ data }) => data));

    // TEST DATA
    const nounId = 1;
    const NounsDescriptorContractAddress = NounsDescriptorContract.address;

    const seed = await NounsSeederContract.generateSeed(
      nounId,
      NounsDescriptorContractAddress
    );
    console.log(seed.toString());

    const svg = await NounsDescriptorContract.generateSVGImage(seed);
    console.log(svg.toString());
  });
});
