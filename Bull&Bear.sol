// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// Chainlink Imports
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// This import includes functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract BullBear is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, KeeperCompatibleInterface, VRFConsumerBaseV2 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint public interval;
    uint public lastTimeStamp;

    AggregatorV3Interface public priceFeed;
    int256 public currentPrice;

    uint256[] public s_randomWords;
    uint256 public requestId;
    uint32 public callbackGasLimit = 500000;
    uint64 public s_subscriptionId = 8402;
    bytes32 keyHash =  0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    VRFCoordinatorV2Interface public COORDINATOR;


    enum MarketTrend{BULL, BEAR}
    MarketTrend public currentMarketTrend = MarketTrend.BULL;

    string[] bullUrisIpfs = [
        "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json",
        "https://ipfs.io/ipfs/QmRJVFeMrtYS2CUVUM2cHJpBV5aX2xurpnsfZxLTTQbiD3?filename=party_bull.json",
        "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json"
    ];

    string[] bearUrisIpfs = [
        "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json",
        "https://ipfs.io/ipfs/QmTVLyTSuiKGUEmb88BgXG3qNC8YgpHZiFbjHrXKH3QHEu?filename=coolio_bear.json",
        "https://ipfs.io/ipfs/Qmdx9Hx7FCDZGExyjLR6vYcnutUR8KhBZBnZfAPHiUommN?filename=beanie_bear.json"
    ];

    event TokensUpdated(string marketTrend);

    constructor(uint updateInterval, address _priceFeed, address _vrfCoordinator) ERC721("Bull&Bear", "BBTK") VRFConsumerBaseV2(_vrfCoordinator){
        interval = updateInterval;
        lastTimeStamp = block.timestamp;

        priceFeed = AggregatorV3Interface(_priceFeed);

        currentPrice = getLatestPrice();

        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        string memory defaultUri = bullUrisIpfs[0];
        _setTokenURI(tokenId, defaultUri);
    }

    function requestRandomnessForNFTUris() internal {
    // Will revert if subscription is not set and funded.
    requestId = COORDINATOR.requestRandomWords(
      keyHash,
      s_subscriptionId,
      3,
      callbackGasLimit,
      1
    );
  }

  function fulfillRandomWords(
    uint256, /* requestId */
    uint256[] memory randomWords
  ) internal override {
    s_randomWords = randomWords;

    string[] memory urisForTrend = currentMarketTrend == MarketTrend.BULL ? bullUrisIpfs : bearUrisIpfs;
    uint256 idx = randomWords[0] % urisForTrend.length; // use modulo to choose a random index.


    for (uint i = 0; i < _tokenIdCounter.current() ; i++) {
        _setTokenURI(i, urisForTrend[idx]);
    }

    string memory trend = currentMarketTrend == MarketTrend.BULL ? "bullish" : "bearish";

    emit TokensUpdated(trend);
  }

    function checkUpkeep(bytes calldata /*checkData*/) external view override returns (bool upkeepNeeded, bytes memory /*performData*/) {
        upkeepNeeded = block.timestamp - lastTimeStamp > interval;
    }

 function performUpkeep(bytes calldata /* performData */ ) external override {
        if ((block.timestamp - lastTimeStamp) > interval ) {
            lastTimeStamp = block.timestamp;
            int latestPrice =  getLatestPrice();

            if (latestPrice == currentPrice) {
                return;
            }

            if (latestPrice < currentPrice) {
                // bear
                currentMarketTrend = MarketTrend.BEAR;
            } else {
                // bull
                currentMarketTrend = MarketTrend.BULL;
            }


            requestRandomnessForNFTUris();
            currentPrice = latestPrice;
        }
    }

    function getLatestPrice() public view returns (int256) {
       (,int price,,,) = priceFeed.latestRoundData();

       return price;
    }


    function updateAllTokenUris(string memory trend) internal {
        if(compareStrings("bare", trend)) {
            for (uint i = 0; i < _tokenIdCounter.current(); i ++) {
                _setTokenURI(i, bearUrisIpfs[0]);
            }
        } else {
            for (uint i = 0; i< _tokenIdCounter.current(); i ++) {
                _setTokenURI(i, bullUrisIpfs[0]);
            }
        }

        emit TokensUpdated(trend);
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }

    function setInterval(uint256 newInterval) public onlyOwner {
        interval = newInterval;
    }

    function setPriceFeed(address newFeed) public onlyOwner {
        priceFeed = AggregatorV3Interface(newFeed);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
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
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

     function setSubscriptionId(uint64 _id) public onlyOwner {
      s_subscriptionId = _id;
     }


    function setCallbackGasLimit(uint32 maxGas) public onlyOwner {
      callbackGasLimit = maxGas;
    }

    function setVrfCoodinator(address _address) public onlyOwner {
        COORDINATOR = VRFCoordinatorV2Interface(_address);
    }
}