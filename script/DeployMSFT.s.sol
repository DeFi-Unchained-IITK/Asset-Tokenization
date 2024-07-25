// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import {MSFT} from "../src/MSFT.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract DeployMSFT is Script {
    MockV3Aggregator public msftFeedMock;
    MockV3Aggregator public ethUsdFeedMock;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    function run() public {
        vm.startBroadcast();
         msftFeedMock = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
         ethUsdFeedMock = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        
        address ethPriceFeed = address(ethUsdFeedMock) ; 
        address msftPriceFeed = address(msftFeedMock); 
        deployMSFT(msftPriceFeed, ethPriceFeed);
        vm.stopBroadcast();
    }
    function deployMSFT(address msftPriceFeed,address ethPriceFeed) public returns (MSFT) {
        return new MSFT(msftPriceFeed, ethPriceFeed);
    }
}