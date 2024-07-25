// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployMSFT} from "../../script/DeployMSFT.s.sol";
import {MSFT} from "../../src/MSFT.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract MSFTTest is Test {
    DeployMSFT deployMSFT;
    MSFT msft;
    address public user = makeAddr("user");
    uint256 constant STARTING_ETH_BALANCE = 100e18;
    MockV3Aggregator public msftFeedMock;
    MockV3Aggregator public ethUsdFeedMock;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    function setUp() public {
        deployMSFT = new DeployMSFT();
        msftFeedMock = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ethUsdFeedMock = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        address ethFeed = address(ethUsdFeedMock);
        address msftFeed = address(msftFeedMock);
        msft = deployMSFT.deployMSFT(msftFeed, ethFeed);
    }

    function testDeployMSFT() public {
        deployMSFT.run();
    }

    function testCanMintAapl() public {
        vm.deal(user, STARTING_ETH_BALANCE);
        vm.prank(user);
        msft.depositAndmint{ value: 10e18 }(1e18);

        assertEq(msft.balanceOf(user), 1e18);
    }

    function testCanRedeem() public {
        vm.deal(user, STARTING_ETH_BALANCE);
        vm.startPrank(user);
        msft.depositAndmint{ value: 10e18 }(1e18);
        msft.approve(address(msft), 1e18);
        msft.redeemAndBurn(1e18);
        vm.stopPrank();
        assertEq(msft.balanceOf(user), 0);
    }
}