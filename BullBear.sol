// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

//general imports
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//chainlink imports
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

//dev imports
import "hardhat/console.sol";

contract BullBear is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, KeeperCompatibleInterface {
    uint private _nextTokenId;

    //public variables required by Chainlink upkeep
    uint public /*immutable*/ interval;
    uint public lastTimeStamp;

    //implementing the price feed interface provided by Chainlink
    AggregatorV3Interface public priceFeed;
    int256 public currentPrice;
 
    constructor(address initialOwner,uint updateInterval, address _priceFeed)
        ERC721("BullBear", "BLB")
        Ownable(initialOwner)
    {   
        //upkeep interval settings
        interval = updateInterval;
        lastTimeStamp = block.timestamp;

        //set to mock price feed contract
        //BTC/USD price feed contract on Sepolia : https://sepolia.etherscan.io/address/0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
        priceFeed = AggregatorV3Interface(_priceFeed);

        currentPrice = getLatestPrice();
    }

    //ipfs uris for our dynamic NFTs
    string[] bullIpfs = [
        "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json",
        "https://ipfs.io/ipfs/QmRJVFeMrtYS2CUVUM2cHJpBV5aX2xurpnsfZxLTTQbiD3?filename=party_bull.json",
        "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json"
    ];

    string[] bearIpfs = [
        "https://ipfs.io/ipfs/Qmdx9Hx7FCDZGExyjLR6vYcnutUR8KhBZBnZfAPHiUommN?filename=beanie_bear.json",
        "https://ipfs.io/ipfs/QmTVLyTSuiKGUEmb88BgXG3qNC8YgpHZiFbjHrXKH3QHEu?filename=coolio_bear.json",
        "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json"
    ];

    //event when price has changed and token URI is updated
    event TokenUpdated(string marketTrend);

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);

        //defaults to gamer bull NFT image
        string memory defaultUri = bullIpfs[0];
        _setTokenURI(tokenId, defaultUri);
    }

    //checkUpkeep function required by Chainlink -> to know whether or not to perform upkeep
    function checkUpkeep(bytes memory) external view override returns(bool upkeepNeeded, bytes memory /*performData*/){
        //performData is the result of off-chain computations performed by the Chainlink nodes
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    //function to perform the actual upkeep -> will be called by the Chainlink upkeep nodes
    function performUpkeep(bytes calldata) external override{
        //revalidate -> best practices
        if((block.timestamp - lastTimeStamp) > interval){
            lastTimeStamp = block.timestamp;
            int256 lastPrice = getLatestPrice();

            //market hasnt changed
            if(lastPrice == currentPrice){
                return;
            }

            //bear trend
            if(lastPrice < currentPrice){
                updateAllTokenUris("bear");
            }

            //bull trend
            else{
                updateAllTokenUris("bull");
            }

            currentPrice = lastPrice;
        }
    }

    //implementing the get latest price function
    function getLatestPrice() public view returns(int256){
        //we only need the price data
        (,int price,,,) = priceFeed.latestRoundData();
        return price;
    }

    //IMP: internal function to compare the string
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }


    //function to update the token URIs according to the price trend
    function updateAllTokenUris(string memory trend) internal{
        if(compareStrings("bear",trend)){
            for(uint i = 0; i<_nextTokenId; i++){
                _setTokenURI(i, bearIpfs[0]);
            }
        }else{
            for(uint i = 0; i<_nextTokenId; i++){
                _setTokenURI(i, bullIpfs[0]);
            }
        }

        emit TokenUpdated(trend);
    }

    //set a new upkeep interval
    function setInterval(uint256 newInterval) public onlyOwner{
        interval = newInterval;
    }

    //set the new price feed address -> from mock feed to actual chainlink Oracle
    function setPriceFeed(address newFeed) public onlyOwner{
        priceFeed = AggregatorV3Interface(newFeed);
    }

    // The following functions are overrides required by Solidity.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
