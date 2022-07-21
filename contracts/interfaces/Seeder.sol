// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface INounsSeeder {
    struct Seed {
        uint48 background;
        uint48 body;
        uint48 accessory;
        uint48 head;
        uint48 glasses;
    }
}
