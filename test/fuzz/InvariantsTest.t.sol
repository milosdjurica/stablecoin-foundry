// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// 1. Total supply of DSC should be less than the total value of collateral
// 2. Getter view functions should never revert -> evergreen invariant

import {Test, console} from "lib/forge-std/src/Test.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    DeployDsc deployer;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDsc();
        (dsc, engine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        // targetContract(address(engine));
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreCollateralThanDsc() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("wethValue -> ", wethValue);
        console.log("wbtcValue -> ", wbtcValue);
        console.log("totalSupply -> ", totalSupply);

        console.log("Times mint is called -> ", handler.timesMintIsCalled());
        assert(wethValue + wbtcValue >= totalSupply);
    }
}
