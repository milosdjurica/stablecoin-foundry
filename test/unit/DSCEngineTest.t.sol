// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "lib/forge-std/src/Test.sol";

import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

contract DSCEngineTest is Test {
    DeployDsc deployer;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    address ethUsdPriceFeed;
    address weth;

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();
    }

    // * PriceFeed Tests
    function testGetUsdValue() public {}
}
