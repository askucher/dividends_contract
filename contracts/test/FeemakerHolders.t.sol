// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FeemakerHolders} from "../src/FeemakerHolders.sol";

contract FeemakerHoldersTest is Test {
    receive() external payable {}

    FeemakerHolders public holders;

    function setUp() public {
        holders = new FeemakerHolders(100 ether);
    }

    function _sendEthToContract(address from, uint256 amount) internal {
        vm.deal(from, amount);
        vm.prank(from);
        (bool ok, ) = address(holders).call{value: amount}("");
        require(ok, "send failed");
    }

    function test_DistributeSingleHolder() public {
        // All supply owned by this contract
        assertEq(holders.totalSupply(), 100 ether);
        assertEq(holders.balanceOf(address(this)), 100 ether);

        // Fund dividends: 1 ether from an external payer
        _sendEthToContract(address(0xBEEF), 1 ether);

        // Entire dividend is withdrawable by the sole holder
        assertEq(holders.withdrawableDividendOf(address(this)), 1 ether);

        uint256 beforeBal = address(this).balance;
        holders.withdrawDividend();
        assertEq(address(this).balance, beforeBal + 1 ether);
        assertEq(holders.withdrawableDividendOf(address(this)), 0);
    }

    function test_DistributeAfterPartialTransfer() public {
        address alice = address(this);
        address bob = address(0xB0B);

        // Transfer 25% of supply to Bob
        holders.transfer(bob, 25 ether);
        assertEq(holders.balanceOf(alice), 75 ether);
        assertEq(holders.balanceOf(bob), 25 ether);

        // Distribute 1 ether after the transfer
        _sendEthToContract(address(0xCAFE), 1 ether);

        // Expected split 75% / 25%
        assertEq(holders.withdrawableDividendOf(alice), 0.75 ether);
        assertEq(holders.withdrawableDividendOf(bob), 0.25 ether);

        // Withdraw and verify balances get credited correctly
        uint256 aliceBefore = alice.balance;
        holders.withdrawDividend();
        assertEq(alice.balance, aliceBefore + 0.75 ether);

        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        holders.withdrawDividend();
        assertEq(bob.balance, bobBefore + 0.25 ether);
    }

    function test_DistributeBeforeAndAfterTransfer() public {
        address alice = address(this); // initial holder of all tokens
        address bob = address(0xB0B);

        // 1) Distribute BEFORE any transfer
        _sendEthToContract(address(0xD1), 1 ether);

        // All of the first 1 ether belongs to Alice
        assertEq(holders.withdrawableDividendOf(alice), 1 ether);
        assertEq(holders.withdrawableDividendOf(bob), 0);

        // 2) Transfer 25% of supply to Bob AFTER the first distribution
        holders.transfer(bob, 25 ether);
        assertEq(holders.balanceOf(alice), 75 ether);
        assertEq(holders.balanceOf(bob), 25 ether);

        // The first distribution remains with Alice after transfer
        assertEq(holders.withdrawableDividendOf(alice), 1 ether);
        assertEq(holders.withdrawableDividendOf(bob), 0);

        // 3) Distribute AGAIN AFTER the transfer
        _sendEthToContract(address(0xD2), 1 ether);

        // Now 1 ether gets split by 75/25
        assertEq(holders.withdrawableDividendOf(alice), 1 ether + 0.75 ether);
        assertEq(holders.withdrawableDividendOf(bob), 0.25 ether);

        // Withdrawals settle amounts
        uint256 aliceBefore = alice.balance;
        holders.withdrawDividend();
        assertEq(alice.balance, aliceBefore + 1.75 ether);

        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        holders.withdrawDividend();
        assertEq(bob.balance, bobBefore + 0.25 ether);
    }
}
