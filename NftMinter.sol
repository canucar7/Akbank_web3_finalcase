// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IContent.sol";

import "hardhat/console.sol";  //It's helpful in finding problems.

contract CanToken is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds; //this number can only ever increase in our contract, we know that whatever the current count is
    mapping(uint256 => IContent.Item) Content; //using token ids to locate the NFT data in the Contents map.
    uint256 price = 5000000000000000;  //price of the NFT in Wei. About 0.005 ETH.

    address public renderingContractAddress; //When this NFT's data is requested, we'll send all of the data to this contract address for rendering.

    event NewItem(address sender, uint256 tokenId, string name); //creating a new NFT, the contract will shout this information out to the world

    constructor() ERC721("CanToken", "CAN") {}

    function generateNFT(
        string calldata ItemName,
        string calldata description,
        uint256[6] calldata Magic 
    ) public payable virtual {
        require(msg.value >= price, "Not enough ETH sent; check price!"); //need to supply the right amount of currency

        uint256 newItemId = _tokenIds.current(); //increment this number at the end

        if (newItemId >= 10000) { //creating a limit and if the token id exceeds this number, cancel the transaction. 
            revert("This NFT is sold out.");
        }

        IContent.Item memory Item; //create a new item instance. `Item` is our data structure for our NFT. 

        Item.name = ItemName;
        Item.magic = Magic;

        Item.seed = uint256(  //seed value will be used as part of a random number generator. 
            keccak256(
                abi.encodePacked( //combines all the pieces of information into one big string.
                    newItemId,
                    msg.sender,
                    block.difficulty,
                    block.timestamp
                )
            )
        );

        _safeMint(msg.sender, newItemId); //transfers the token id to the user, creates and gives the NFT to the user.

        Content[newItemId] = Item; //Store our item in the content "map" using the token id

        emit NewItem(msg.sender, newItemId, ItemName); //send out our notification event.

        _tokenIds.increment();
    }

    function setRenderingContractAddress(address _renderingContractAddress)// Only the contract owner can use this function
        public
        onlyOwner
    {
        renderingContractAddress = _renderingContractAddress; //onlyOwner stops everyone but the owner from setting the render contract address.
    }

    function setPrice(uint256 _price) public onlyOwner { //the owner of the contract can set the price to mint the NFT.
        price = _price;
    }

    function totalContent() public view virtual returns (uint256) { //This function returns the current count for the NFTs
        return _tokenIds.current();
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory) //Anyone can call this function with a token id and see the NFT.
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (renderingContractAddress == address(0)) {
            return "";
        }

        IItemRenderer renderer = IItemRenderer(renderingContractAddress);
        return renderer.tokenURI(_tokenId, Content[_tokenId]); //we pass the token id and the NFT content we stored earlier.
    }

    //withdrawal function is public, and anyone can access it, but only the owner can run it
    //nonReentrant prevent a reentrancy attack on this function.
    function withdraw() public onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");//address(this).balance is the entire balance of the contract. So we'll transfer everything to the wallet.
        require(success, "Withdrawal failed");
    }
    
}