// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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
 * It is similar to DAI if DAI had no governance, no fees and was only backed by WETH and WBTC.
 *
 * Our DSC System should always be "overcollateralized". At no point, should the value of
 * all collateral <= the $ backed value of all the DSC.
 *
 * @notice This contract is the core of DSC System. It handles all the logic for minting
 * and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */
// Decentralized Stablecoin Engine
contract DSCEngine {
    ////////////////////
    // * Errors 	  //
    ////////////////////
    error DSCEngine__MustBeMoreThanZero();

    ////////////////////
    // * Types 		  //
    ////////////////////

    ////////////////////
    // * Variables	  //
    ////////////////////

    ////////////////////
    // * Events 	  //
    ////////////////////

    ////////////////////
    // * Modifiers 	  //
    ////////////////////
    modifier moreThanZero(uint amount) {
        if (amount <= 0) revert DSCEngine__MustBeMoreThanZero();
        _;
    }

    ////////////////////
    // * Functions	  //
    ////////////////////

    ////////////////////
    // * Constructor  //
    ////////////////////
    constructor() {}

    ////////////////////////////
    // * Receive & Fallback   //
    ////////////////////////////

    ////////////////////
    // * External 	  //
    ////////////////////

    function depositCollateralAndMintDsc() external {}

    /**
     *
     * @param tokenCollateralAddress Address of the token to deposit as collaterall (wBTC OR wETH)
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint amountCollateral
    ) external moreThanZero(amountCollateral) {}

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

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
}
