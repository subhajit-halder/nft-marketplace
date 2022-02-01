const { expect } = require("chai");
const { ethers } = require("hardhat");

describe.only("NFTMarket_royalty", function () {
  it("If royalty is working", async function () {
    // deploy market
    const Market = await ethers.getContractFactory("NFTMarket_royalty");
    const ownerListingPrice = await ethers.utils.parseUnits("10", "ether");
    // const market = await Market.deploy(ownerListingPrice);
    const market = await Market.deploy();
    await market.deployed();
    // market.setListingPrice(ownerListingPrice);
    const marketAddress = market.address;

    // provider
    provider = ethers.provider;

    // deploy nft
    const NFT = await ethers.getContractFactory("NFT");
    const nft = await NFT.deploy(marketAddress);
    await nft.deployed();
    const nftContractAddress = nft.address;

    // get listing price
    let listingPrice = await market.getListingPrice();
    listingPrice = listingPrice.toString();

    // selling price
    const auctionPrice = await ethers.utils.parseUnits("100", "ether");

    // creating the tokens
    await nft.createToken("https://www.firstNft.com");
    await nft.createToken("https://www.secondNft.com");

    // listing tokens
    await market.createMarketItem(nftContractAddress, 1, auctionPrice, {
      value: listingPrice,
    });
    await market.createMarketItem(nftContractAddress, 2, auctionPrice, {
      value: listingPrice,
    });

    // get reference to second address, which will be the buyer
    const [ownerAddress, buyerAddress] = await ethers.getSigners();

    // sell nft 1 to the buyer
    await market
      .connect(buyerAddress)
      .createMarketSale(nftContractAddress, 1, { value: auctionPrice });

    items = await market.fetchMarketItems();
    items = await Promise.all(
      items.map(async (i) => {
        const tokenUri = await nft.tokenURI(i.tokenId);
        let item = {
          price: i.price.toString(),
          tokenId: i.tokenId.toString(),
          seller: i.seller,
          owner: i.owner,
          creator: i.creator,
          tokenUri,
        };
        return item;
      })
    );

    let sellerBalance = console.log("items: ", items);
    console.log("listing price", await market.getListingPrice().toString());
    console.log("owner listing price", ownerListingPrice.toString());
    console.log(
      "buyer balance",
      await provider.getBalance(buyerAddress.address)
    );
    console.log(
      "owner balance",
      await provider.getBalance(ownerAddress.address)
    );
  });
});
