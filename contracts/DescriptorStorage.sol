// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {INounsSeeder} from "./interfaces/Seeder.sol";
import {MultiPartRLEToSVG} from "./libs/MultiPartRLEToSVG.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {Base64} from "base64-sol/base64.sol";

import "./Master.sol";

contract DescriptorStorage is Ownable {
    using Strings for uint256;

    bytes32 constant COPYRIGHT_CC0_1_0_UNIVERSAL_LICENSE =
        0xa2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499;

    // Whether or not new Noun parts can be added
    bool public arePartsLocked;

    // Whether or not `tokenURI` should be returned as a data URI (Default: true)
    bool public isDataURIEnabled = true;

    // Base URI
    string public baseURI;

    // Noun Color Palettes (Index => Hex Colors)
    mapping(uint8 => string[]) public palettes;

    // // /////////////////////////////////////////////////////////////// MULTIPART DETAILS

    // Noun Backgrounds (Hex Colors)
    string[] public backgrounds;

    // Noun Bodies (Custom RLE)
    bytes[] public bodies;

    // Noun Accessories (Custom RLE)
    bytes[] public accessories;

    // Noun Heads (Custom RLE)
    bytes[] public heads;

    // Noun Glasses (Custom RLE)
    bytes[] public glasses;

    // // /////////////////////////////////////////////////////////////// SET MULTIPART DETAILS

    function addManyColorsToPalette(
        uint8 paletteIndex,
        string[] calldata newColors
    ) external onlyOwner {
        require(
            palettes[paletteIndex].length + newColors.length <= 256,
            "Palettes can only hold 256 colors"
        );
        for (uint256 i = 0; i < newColors.length; i++) {
            _addColorToPalette(paletteIndex, newColors[i]);
        }
    }

    function addManyBackgrounds(string[] calldata _backgrounds)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _backgrounds.length; i++) {
            _addBackground(_backgrounds[i]);
        }
    }

    function _addBackground(string calldata _background) internal {
        backgrounds.push(_background);
    }

    function addManyBodies(bytes[] calldata _bodies) external onlyOwner {
        for (uint256 i = 0; i < _bodies.length; i++) {
            _addBody(_bodies[i]);
        }
    }

    function _addBody(bytes calldata _body) internal {
        bodies.push(_body);
    }

    function addManyAccessories(bytes[] calldata _accessories)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _accessories.length; i++) {
            _addAccessory(_accessories[i]);
        }
    }

    function _addAccessory(bytes calldata _accessory) internal {
        accessories.push(_accessory);
    }

    function addManyHeads(bytes[] calldata _heads) external onlyOwner {
        for (uint256 i = 0; i < _heads.length; i++) {
            _addHead(_heads[i]);
        }
    }

    function _addHead(bytes calldata _head) internal {
        heads.push(_head);
    }

    function addManyGlasses(bytes[] calldata _glasses) external onlyOwner {
        for (uint256 i = 0; i < _glasses.length; i++) {
            _addGlasses(_glasses[i]);
        }
    }

    function _addGlasses(bytes calldata _glasses) internal {
        glasses.push(_glasses);
    }

    function addColorToPalette(uint8 _paletteIndex, string calldata _color)
        external
        onlyOwner
    {
        require(
            palettes[_paletteIndex].length <= 255,
            "Palettes can only hold 256 colors"
        );
        _addColorToPalette(_paletteIndex, _color);
    }

    function _addColorToPalette(uint8 _paletteIndex, string calldata _color)
        internal
    {
        palettes[_paletteIndex].push(_color);
    }

    function addBackground(string calldata _background) external onlyOwner {
        _addBackground(_background);
    }

    /**
     * @notice Add a Noun body.
     * @dev This function can only be called by the owner when not locked.
     */
    function addBody(bytes calldata _body) external onlyOwner {
        _addBody(_body);
    }

    /**
     * @notice Add a Noun accessory.
     * @dev This function can only be called by the owner when not locked.
     */
    function addAccessory(bytes calldata _accessory) external onlyOwner {
        _addAccessory(_accessory);
    }

    /**
     * @notice Add a Noun head.
     * @dev This function can only be called by the owner when not locked.
     */
    function addHead(bytes calldata _head) external onlyOwner {
        _addHead(_head);
    }

    /**
     * @notice Add Noun glasses.
     * @dev This function can only be called by the owner when not locked.
     */
    function addGlasses(bytes calldata _glasses) external onlyOwner {
        _addGlasses(_glasses);
    }

    // // /////////////////////////////////////////////////////////////// GET MULTIPART DETAILS

    function getBodyDetails(uint256 _bodyDetails)
        public
        view
        returns (bytes memory)
    {
        return bodies[_bodyDetails];
    }

    function getAccessoriesDetails(uint256 _accessoriesDetails)
        public
        view
        returns (bytes memory)
    {
        return accessories[_accessoriesDetails];
    }

    function getheadsDetails(uint256 _headsDetails)
        public
        view
        returns (bytes memory)
    {
        return heads[_headsDetails];
    }

    function getglassesDetails(uint256 _glassesDetails)
        public
        view
        returns (bytes memory)
    {
        return glasses[_glassesDetails];
    }

    function getbackgroundsDetails(uint256 _backgroundsDetails)
        public
        view
        returns (string memory)
    {
        return backgrounds[_backgroundsDetails];
    }

    function backgroundCount() external view returns (uint256) {
        return backgrounds.length;
    }

    function bodyCount() external view returns (uint256) {
        return bodies.length;
    }

    function accessoryCount() external view returns (uint256) {
        return accessories.length;
    }

    function headCount() external view returns (uint256) {
        return heads.length;
    }

    function glassesCount() external view returns (uint256) {
        return glasses.length;
    }

    // // /////////////////////////////////////////////////////////////// SET SOME INFORMATION
    function setBaseURI(string calldata _baseURI) external {
        baseURI = _baseURI;
    }

    // // /////////////////////////////////////////////////////////////// EMERGENCY

    function generateSVGImage(INounsSeeder.Seed memory seed)
        external
        view
        returns (string memory)
    {
        MultiPartRLEToSVG.SVGParams memory params = MultiPartRLEToSVG
        .SVGParams({
            parts: _getPartsForSeed(seed),
            background: backgrounds[seed.background]
        });
        return
            Base64.encode(
                bytes(MultiPartRLEToSVG.generateSVG(params, palettes))
            );
    }

    function _getPartsForSeed(INounsSeeder.Seed memory seed)
        internal
        view
        returns (bytes[] memory)
    {
        bytes[] memory _parts = new bytes[](4);
        _parts[0] = getBodyDetails(seed.body);
        _parts[1] = getAccessoriesDetails(seed.accessory);
        _parts[2] = getheadsDetails(seed.head);
        _parts[3] = getglassesDetails(seed.glasses);
        return _parts;
    }
}
