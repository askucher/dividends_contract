// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FeemakerHolders} from "../src/FeemakerHolders.sol";

contract FeemakerHoldersScript is Script {
    FeemakerHolders public holders;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        holders = new FeemakerHolders(100 ether);

        vm.stopBroadcast();
    }
}
