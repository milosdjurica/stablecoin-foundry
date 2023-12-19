// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DSCEngineTest is Test {
    DeployDsc deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;

    function setUp() public {
        deployer = new DeployDsc();
    }
}
