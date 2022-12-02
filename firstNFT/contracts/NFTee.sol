// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import the openzeppplin contracts
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract GameItem is ERC721 {
    constructor() ERC721("GameItem", "ITM") {
        // mint an NFT for yourself
        _mint(msg.sender, 1);
    }
}
