// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Milos Djurica
 * The system is designed to be as minimal as possible, and have the tokens maintain a
 * 1 token == 1$ peg.
 * This stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees and was only backed by wETH and wBTC.
 *
 * Our DSC System should always be "overcollateralized". At no point, should the value of
 * all collateral <= the $ backed value of all the DSC.
 *
 * @notice This contract is the core of DSC System. It handles all the logic for minting
 * and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */
// Decentralized Stablecoin Engine
contract DSCEngine is ReentrancyGuard {
    ////////////////////
    // * Errors 	  //
    ////////////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAddressNotAllowed();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DESCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsBroken(uint256 healthFactor);
    error DESCEngine__MintFailed();

    ////////////////////
    // * Types 		  //
    ////////////////////

    ////////////////////
    // * Variables	  //
    ////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    DecentralizedStableCoin private immutable i_dsc;

    mapping(address token => address priceFeed) private s_priceFeeds; // s_tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DscMinted;

    address[] private s_collateralTokens;
    ////////////////////
    // * Events 	  //
    ////////////////////

    event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);
    event CollateralRedeemed(address indexed user, address indexed tokenAddress, uint256 indexed amount);

    ////////////////////
    // * Modifiers 	  //
    ////////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) revert DSCEngine__MustBeMoreThanZero();
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert DSCEngine__TokenAddressNotAllowed();
        }
        _;
    }

    ////////////////////
    // * Functions	  //
    ////////////////////

    ////////////////////
    // * Constructor  //
    ////////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ////////////////////////////
    // * Receive & Fallback   //
    ////////////////////////////

    ////////////////////
    // * External 	  //
    ////////////////////

    /**
     *
     * @param tokenCollateral The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDscToMint The amount of DSC to mint
     * @notice This func will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(address tokenCollateral, uint256 amountCollateral, uint256 amountDscToMint)
        external
    {
        depositCollateral(tokenCollateral, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     *
     * @param tokenCollateralAddress Address of the token to deposit as collaterall (wBTC OR wETH)
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);

        if (!success) revert DESCEngine__TransferFailed();
    }

    /**
     *
     * @param tokenCollateralAddress Address of collateral token to redeem
     * @param amountCollateral Amount of collateral to redeem
     * @param amountDscToBurn Amount of DSC to burn
     *
     * This function burns DSC and redeems collateral in one transaction
     */
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeem collateral already checks if health factor is broken
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);

        if (!success) revert DESCEngine__TransferFailed();
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Follows CEI
     * @param amountDscToMint The Amount of Decentralized Stablecoin to mint
     * @notice They must have more collateral value than the minimum threshold
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) revert DESCEngine__MintFailed();
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) {
        s_DscMinted[msg.sender] -= amount;
        bool success = i_dsc.transferFrom(msg.sender, address(this), amount);

        if (!success) revert DESCEngine__TransferFailed();
        i_dsc.burn(amount);
        _revertIfHealthFactorIsBroken(msg.sender); // this is probably not needed
    }

    function liquidate() external {}

    function getHealthFactor() external view {}

    ////////////////////
    // * Public 	  //
    ////////////////////

    ////////////////////
    // * Internal 	  //
    ////////////////////

    ////////////////////
    // * Private 	  //
    ////////////////////

    ////////////////////
    // * View & Pure  //
    ////////////////////

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // If 1 ETH = $1000 -> The returned value from ChainLink will be 1000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) revert DSCEngine__HealthFactorIsBroken(userHealthFactor);
    }

    /**
     *
     * @param user Address of user
     * @notice Returns how close user is to the liquidation
     * If user goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        // total dscMinted
        // total collateral VALUE (in $USD)
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = _getAccountInformation(user);

        uint256 collateralAdjustedForThreshold =
            (totalCollateralValueInUsd * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION);
        // ! USER MUST HAVE DOUBLE MORE COLLATERAL THAN DEPOSITED !!!!
        // $1000 ETH / 100 DSC
        // 1000 * 50 / 100 / 100 > 1
        // *50/100 can be only /2 -> 1000 / 2 / 100 = 5 >>> 1
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd)
    {
        totalDscMinted = s_DscMinted[user];

        totalCollateralValueInUsd = getAccountCollateralValue(user);
    }
}
