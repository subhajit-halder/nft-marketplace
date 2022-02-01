// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

contract NFTMarket_royalty is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    IERC721ReceiverUpgradeable
{
    using AddressUpgradeable for address payable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeMathUpgradeable for uint256;
    CountersUpgradeable.Counter private _itemIds;
    CountersUpgradeable.Counter private _itemsSold;

    uint256 listingPrice;

    function initialize() public initializer {
        OwnableUpgradeable.__Ownable_init();
        listingPrice = 1.0 ether;
    }

    // constructor (uint256 price) {
    //   setListingPrice(price);
    // }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        address payable creator;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    // Assume tokenUri doesn't change, so don't add to other events
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        address creator,
        uint256 price,
        bool sold,
        string tokenUri
    );

    event MarketItemListed(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        address creator,
        uint256 price,
        bool sold
    );

    event MarketItemPriceChanged(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        address creator,
        uint256 price,
        bool sold
    );

    // Include marketAddress so we can display it when displaying these events
    // (marketAddress = from, owner = to)
    //
    // Seller here is the person who listed, not the address of the market
    event MarketItemSold(
        uint256 indexed itemId,
        address nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        address owner,
        address creator,
        uint256 price,
        bool sold,
        address marketAddress
    );

    /**
     * Returns the listing price of the contract
     */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function setListingPrice(uint256 price) public onlyOwner {
        listingPrice = price;
    }

    ///
    /// LISTING + BUYING/SELLING
    ///

    /**
     * Places an item for sale on the marketplace
     */
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            // Seller
            payable(msg.sender),
            // Owner
            payable(address(this)),
            // Creator
            payable(msg.sender),
            price,
            false
        );

        string memory tokenUri = ERC721URIStorage(nftContract).tokenURI(
            tokenId
        );
        IERC721(nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            // Seller
            msg.sender,
            // Owner
            address(this),
            // Creator
            msg.sender,
            price,
            false,
            tokenUri
        );
    }

    /**
     * Creates the sale of a marketplace item
     * Transfers ownership of the item, as well as funds between parties
     */
    function createMarketSale(
      address nftContract,
       uint256 itemId
      )public payable nonReentrant {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        // If msg.value is too low (e.g. 1 wei), marketCut will be 0
        uint256 marketCut = (msg.value).div(100).mul(3);
        uint256 sellerCut = msg.value.sub(marketCut);
        uint256 creatorCut = 0;
        if (idToMarketItem[itemId].creator != idToMarketItem[itemId].seller) {
            // Creator gets 10% royalties (if msg.value is high enough).
            creatorCut = (msg.value).div(100).mul(10);
            sellerCut = sellerCut.sub(creatorCut);
            idToMarketItem[itemId].creator.sendValue(creatorCut);
        }

        address oldSeller = idToMarketItem[itemId].seller;
        idToMarketItem[itemId].seller.sendValue(sellerCut);
        IERC721(nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].seller = payable(address(0));
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();

        // Transfer money from this contract to the contract's owner!
        payable(owner()).sendValue(getBalance());

        emit MarketItemSold(
            itemId,
            nftContract,
            idToMarketItem[itemId].tokenId,
            // Seller. Don't emit an address of 0 so we can filter on seller
            oldSeller,
            // Owner
            idToMarketItem[itemId].owner,
            // Creator
            idToMarketItem[itemId].creator,
            price,
            true,
            address(this)
        );
    }

    /**
     * Lets someone who bought an NFT list it on the marketplace
     *
     * NOTE: NFTContract.approve needs to be called in order for this to work.
     */
    function listMarketItem(
        address nftContract,
        uint256 itemId,
        uint256 price
    ) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        MarketItem storage _item = idToMarketItem[itemId];
        _item.owner = payable(address(this));
        _item.price = price;
        _item.seller = payable(msg.sender);
        _item.sold = false;
        _itemsSold.decrement();

        _item.seller.sendValue(msg.value);
        IERC721(nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            _item.tokenId
        );

        emit MarketItemListed(
            itemId,
            nftContract,
            _item.tokenId,
            msg.sender,
            address(this),
            _item.creator,
            price,
            false
        );
    }

    /**
     * Lets seller of a currently listed item update the price.
     */
    function updateMarketItemPrice(
        address nftContract,
        uint256 itemId,
        uint256 price
    ) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");

        MarketItem storage _item = idToMarketItem[itemId];
        require(
            _item.seller == _msgSender(),
            "Caller is not the item's seller and cannot change the price"
        );
        require(
            _item.owner == address(this),
            "You can only update the price of a listed item"
        );

        _item.price = price;

        emit MarketItemPriceChanged(
            itemId,
            nftContract,
            _item.tokenId,
            _item.seller,
            _item.owner,
            _item.creator,
            price,
            false
        );
    }

    ///
    /// FETCH FUNCTIONS
    ///

    /**
     * Fetches an item based on the passed-in ID.
     */
    function fetchItemForId(uint256 itemId)
        public
        view
        returns (MarketItem memory)
    {
        require(itemId <= _itemIds.current(), "itemId must be valid");
        return idToMarketItem[itemId];
    }

    /**
     * Fetches only items a user has created
     */
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        return _fetchNfts(msg.sender, this._getCreator);
    }

    function fetchItemsCreatedBy(address addr)
        public
        view
        returns (MarketItem[] memory)
    {
        return _fetchNfts(addr, this._getCreator);
    }

    /**
     * Fetches only items a user is selling in the marketplace.
     */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        return _fetchNfts(msg.sender, this._getSeller);
    }

    function fetchItemsListedBy(address addr)
        public
        view
        returns (MarketItem[] memory)
    {
        return _fetchNfts(addr, this._getSeller);
    }

    /**
     * Fetches all unsold market items
     */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        return _fetchNfts(address(this), this._getOwner);
    }

    /**
     * Fetches items that a user currently owns.
     * A user owns an NFT if they purchased it and have not listed it back on the marketplace.
     */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        return _fetchNfts(msg.sender, this._getOwner);
    }

    function fetchItemsOwnedBy(address addr)
        public
        view
        returns (MarketItem[] memory)
    {
        return _fetchNfts(addr, this._getOwner);
    }

    ///
    /// MISC
    ///

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    ///
    /// PRIVATE/INTERNAL FUNCTIONS
    ///

    function _fetchNfts(
        address addr,
        function(MarketItem memory) external pure returns (address) getAddr
    ) private view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (getAddr(idToMarketItem[i + 1]) == addr) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (getAddr(idToMarketItem[i + 1]) == addr) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Doesn't work if this function is internal, not sure why
    function _getCreator(MarketItem memory marketItem)
        external
        pure
        returns (address)
    {
        return marketItem.creator;
    }

    // Doesn't work if this function is internal, not sure why
    function _getOwner(MarketItem memory marketItem)
        external
        pure
        returns (address)
    {
        return marketItem.owner;
    }

    // Doesn't work if this function is internal, not sure why
    function _getSeller(MarketItem memory marketItem)
        external
        pure
        returns (address)
    {
        return marketItem.seller;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        // See https://docs.openzeppelin.com/contracts/2.x/api/token/erc721#ERC721-safeTransferFrom-address-address-uint256-
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}