// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "lib/forge-std/src/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract DeployDsc is Script {
    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        vm.startBroadcast();

        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine dscEngine = new DSCEngine([], [], dsc);

        vm.stopBroadcast();
    }
}
