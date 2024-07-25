// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OracleLib, AggregatorV3Interface} from "./library/OracleLib.sol";



contract MSFT is ERC20 {
    using OracleLib for AggregatorV3Interface;

    error msft_feeds__InsufficientCollateral();

    // These both have 8 decimal places for Polygon
    // https://docs.chain.link/data-feeds/price-feeds/addresses?network=polygon
    address private i_msftFeed;
    address private i_ethUsdFeed;
    uint256 public constant DECIMALS = 8;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address user => uint256 msftMinted) public s_msftMintedPerUser;
    mapping(address user => uint256 ethCollateral) public s_ethCollateralPerUser;

    constructor(address msftFeed, address ethUsdFeed) ERC20("Token Microsoft", "MSFT") {
        i_msftFeed = msftFeed;
        i_ethUsdFeed = ethUsdFeed;
    }

    /* 
     * @dev User must deposit at least 200% of the value of the msft they want to mint
     */
    
    function depositAndmint(uint256 amountToMint) external payable {
        // Checks / Effects
        s_ethCollateralPerUser[msg.sender] += msg.value;
        s_msftMintedPerUser[msg.sender] += amountToMint;

        uint256 healthFactor = getHealthFactor(msg.sender);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert msft_feeds__InsufficientCollateral();
        }
        _mint(msg.sender, amountToMint);
    }

    function redeemAndBurn(uint256 amountToRedeem) external {
        // Checks / Effects
        uint256 valueRedeemed = getUsdAmountFrommsft(amountToRedeem);
        uint256 ethToReturn = getEthAmountFromUsd(valueRedeemed);
        s_msftMintedPerUser[msg.sender] -= amountToRedeem;
        uint256 healthFactor = getHealthFactor(msg.sender);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert msft_feeds__InsufficientCollateral();
        }
        _burn(msg.sender, amountToRedeem);

        (bool success,) = msg.sender.call{value: ethToReturn}("");
        if (!success) {
            revert("msft_feeds: transfer failed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getHealthFactor(address user) public view returns (uint256) {
        (uint256 totalmsftMintedValueInUsd, uint256 totalCollateralEthValueInUsd) = getAccountInformationValue(user);
        return _calculateHealthFactor(totalmsftMintedValueInUsd, totalCollateralEthValueInUsd);
    }

    function getUsdAmountFrommsft(uint256 amountmsftInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_msftFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (amountmsftInWei * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getUsdAmountFromEth(uint256 ethAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_ethUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (ethAmountInWei * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getEthAmountFromUsd(uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_ethUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (usdAmountInWei * PRECISION) / ((uint256(price) * ADDITIONAL_FEED_PRECISION) * PRECISION);
    }

    function getAccountInformationValue(address user)
        public
        view
        returns (uint256 totalmsftMintedValueUsd, uint256 totalCollateralValueUsd)
    {
        (uint256 totalmsftMinted, uint256 totalCollateralEth) = _getAccountInformation(user);
        totalmsftMintedValueUsd = getUsdAmountFrommsft(totalmsftMinted);
        totalCollateralValueUsd = getUsdAmountFromEth(totalCollateralEth);
    }

    function _calculateHealthFactor(uint256 msftMintedValueUsd, uint256 collateralValueUsd)
        internal
        pure
        returns (uint256)
    {
        if (msftMintedValueUsd == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / msftMintedValueUsd;
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalmsftMinted, uint256 totalCollateralEth)
    {
        totalmsftMinted = s_msftMintedPerUser[user];
        totalCollateralEth = s_ethCollateralPerUser[user];
    }
}