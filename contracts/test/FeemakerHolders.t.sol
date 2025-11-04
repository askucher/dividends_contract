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

    function test_DistributeAfterPartialTransferComplex() public {
        address alice = address(this);
        address bob = address(0xB0B);
        address charlie = address(0xC0C);

        // Transfer 25% of supply to Bob
        holders.transfer(bob, 25 ether);
        assertEq(holders.balanceOf(alice), 75 ether);
        assertEq(holders.balanceOf(bob), 25 ether);
        assertEq(holders.balanceOf(charlie), 0 ether);

        // Distribute 1 ether after the transfer
        _sendEthToContract(address(0xCAFE), 1 ether);

        // Expected split 75% / 25%
        assertEq(holders.withdrawableDividendOf(alice), 0.75 ether);
        assertEq(holders.withdrawableDividendOf(bob), 0.25 ether);

        // Withdraw and verify balances get credited correctly
        uint256 aliceBefore = alice.balance;
        holders.withdrawDividend();
        assertEq(alice.balance, aliceBefore + 0.75 ether);

        // Bob transfers half of his tokens (12.5 ether) to Charlie
        vm.prank(bob);
        holders.transfer(charlie, 12.5 ether);

        // Check correctness of token balances
        assertEq(holders.balanceOf(alice), 75 ether);
        assertEq(holders.balanceOf(bob), 12.5 ether);
        assertEq(holders.balanceOf(charlie), 12.5 ether);

        // Charlie has no past dividends; withdrawing should yield zero
        uint256 charlieBefore = charlie.balance;
        vm.prank(charlie);
        holders.withdrawDividend();
        assertEq(charlie.balance, charlieBefore);

        // Bob can withdraw his previously accrued dividends (0.25 ether)
        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        holders.withdrawDividend();
        assertEq(bob.balance, bobBefore + 0.25 ether);

        _sendEthToContract(address(0xCAFE), 1 ether);

        // Check all withdrawable balances after second distribution (based on 75/12.5/12.5 split)
        assertEq(holders.withdrawableDividendOf(alice), 0.75 ether);
        assertEq(holders.withdrawableDividendOf(bob), 0.125 ether);
        assertEq(holders.withdrawableDividendOf(charlie), 0.125 ether);
    }

    function test_OneWithdraws_OtherDoesNot_ThenNewIncome() public {
        address alice = address(this);
        address bob = address(0xB0B);

        // Split supply 75/25
        holders.transfer(bob, 25 ether);
        assertEq(holders.balanceOf(alice), 75 ether);
        assertEq(holders.balanceOf(bob), 25 ether);

        // First distribution: 1 ether
        _sendEthToContract(address(0xD00D), 1 ether);
        assertEq(holders.withdrawableDividendOf(alice), 0.75 ether);
        assertEq(holders.withdrawableDividendOf(bob), 0.25 ether);

        // Alice withdraws; Bob does not
        uint256 aliceBefore = alice.balance;
        holders.withdrawDividend();
        assertEq(alice.balance, aliceBefore + 0.75 ether);

        // After Alice's withdrawal, only Bob still has 0.25 ether pending
        assertEq(holders.withdrawableDividendOf(alice), 0);
        assertEq(holders.withdrawableDividendOf(bob), 0.25 ether);

        // New income arrives
        _sendEthToContract(address(0xF00D), 1 ether);

        // Now withdrawables should include previous unclaimed + new portion
        // Alice: only the new 0.75 ether
        // Bob: previous 0.25 ether + new 0.25 ether = 0.5 ether
        assertEq(holders.withdrawableDividendOf(alice), 0.75 ether);
        assertEq(holders.withdrawableDividendOf(bob), 0.5 ether);
    }

    function test_ManyDistributions_WithMidwayWithdrawals() public {
        address alice = address(this);
        address bob = address(0xB0B);
        address charlie = address(0xC0C);

        // Initial split: Alice 75, Bob 25
        holders.transfer(bob, 25 ether);
        assertEq(holders.balanceOf(alice), 75 ether);
        assertEq(holders.balanceOf(bob), 25 ether);

        // Bob transfers half to Charlie → 75 / 12.5 / 12.5
        vm.prank(bob);
        holders.transfer(charlie, 12.5 ether);
        assertEq(holders.balanceOf(alice), 75 ether);
        assertEq(holders.balanceOf(bob), 12.5 ether);
        assertEq(holders.balanceOf(charlie), 12.5 ether);

        // 51 incomes of 1 ether
        // - Bob withdraws after 5 incomes
        // - Alice withdraws after 15 incomes
        for (uint256 i = 0; i < 51; i++) {
            _sendEthToContract(address(uint160(0xD00D + i)), 1 ether);

            if (i == 4) {
                // after 5 incomes
                uint256 bobBefore = bob.balance;
                vm.prank(bob);
                holders.withdrawDividend();
                // Bob share per income = 12.5% = 1/8 ether → 5/8 ether total so far
                assertEq(bob.balance, bobBefore + (5 * 1 ether) / 8);
            }

            if (i == 14) {
                // after 15 incomes
                uint256 aliceBefore = alice.balance;
                holders.withdrawDividend();
                // Alice share per income = 75% = 3/4 ether → 15 * 3/4 = 11.25 ether
                assertEq(alice.balance, aliceBefore + (15 * 1 ether * 3) / 4);
            }
        }

        // Final expected withdrawables:
        // - Alice withdrew after 15 → remaining 36 incomes * 3/4 ether = 27 ether
        // - Bob withdrew after 5 → remaining 46 incomes * 1/8 ether = 5.75 ether
        // - Charlie never withdrew → 51 incomes * 1/8 ether = 6.375 ether
        assertEq(holders.withdrawableDividendOf(alice), (36 * 1 ether * 3) / 4);
        assertEq(holders.withdrawableDividendOf(bob), (46 * 1 ether) / 8);
        assertEq(holders.withdrawableDividendOf(charlie), (51 * 1 ether) / 8);
    }
}
