// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// 1. Total supply of DSC should be less than the total value of collateral
// 2. Getter view functions should never revert -> evergreen invariant

import {Test} from "lib/forge-std/src/Test.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";

import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract InvariantTest is StdInvariant, Test {
    DeployDsc deployer;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    DSCEngine engine;

    function setUp() external {
        deployer = new DeployDsc();
        (dsc, engine, config) = deployer.run();
    }
}
