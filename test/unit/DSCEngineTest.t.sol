// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "lib/forge-std/src/Test.sol";

import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDsc deployer;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    // * Constructor Tests
    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(btcUsdPriceFeed);
        priceFeedAddresses.push(ethUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    // * PriceFeed Tests
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15 * 2000$ = 30,000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        // $100 / $2000
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(expectedWeth, actualWeth);
    }

    // * Deposit Collateral
    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.depositCollateral(weth, 0);

        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randomToken = new ERC20Mock();

        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressNotAllowed.selector);
        engine.depositCollateral(address(randomToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public {}
}
