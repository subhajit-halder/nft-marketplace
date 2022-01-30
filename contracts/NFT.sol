// contracts/NFT.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

contract NFT is ERC721URIStorage {
    using Counters for Counters.Counter; 
    Counters.Counter private _tokenIds; //using counters to increment the tokenId
    address contractAddress;

    // constructor for setting the contract address 
    constructor(address marketplaceAddress) ERC721("Metaverse Tokens", "METT") {
        contractAddress = marketplaceAddress;
    }

    // minting the tokens 
    function createToken(string memory tokenURI) public returns (uint) {
        _tokenIds.increment(); //increment the value of tokenId
        uint256 newItemId = _tokenIds.current();

        _mint(msg.sender, newItemId); //mint the token
        _setTokenURI(newItemId, tokenURI); //this function is from ERC721URIStorage.sol
        setApprovalForAll(contractAddress, true); //give marketplace approval to transact the token 
        return newItemId; //for interacting using frontend
    }
}
