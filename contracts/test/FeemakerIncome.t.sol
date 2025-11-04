// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FeemakerIncome} from "../src/FeemakerIncome.sol";
import {FeemakerHolders} from "../src/FeemakerHolders.sol";

contract FeemakerIncomeTest is Test {
    receive() external payable {}

    FeemakerIncome public income;
    FeemakerHolders public holders;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal charlie = address(0xC0C);

    function setUp() public {
        income = new FeemakerIncome();
        holders = income.holders();
    }

    function _sendEthToHolders(address from, uint256 amount) internal {
        vm.deal(from, amount);
        vm.prank(from);
        (bool ok, ) = address(holders).call{value: amount}("");
        require(ok, "send failed");
    }

    function _moveHolderTokensFromIncome(address to, uint256 amount) internal {
        // The FeemakerIncome contract owns all holder tokens initially.
        // Simulate it transferring tokens to `to` by pranking as the contract.
        vm.prank(address(income));
        holders.transfer(to, amount);
    }

    function test_Metadata() public {
        assertEq(income.name(), "Feemaker Income");
        assertEq(income.symbol(), "WETH");
    }

    function test_TotalSupplyTracksHoldersEthBalance() public {
        assertEq(income.totalSupply(), address(holders).balance);
        _sendEthToHolders(address(0xF00D), 2 ether);
        assertEq(income.totalSupply(), 2 ether);
    }

    function test_BalanceOfReflectsWithdrawableDividend() public {
        // Give Alice 40% of holder tokens, Bob 10%, Income keeps 50%.
        _moveHolderTokensFromIncome(alice, 40 ether);
        _moveHolderTokensFromIncome(bob, 10 ether);

        // Distribute 1 ether to holders.
        _sendEthToHolders(address(0xD1), 1 ether);

        // Check withdrawables through the FeemakerIncome ERC20-view facade.
        assertEq(income.balanceOf(alice), 0.4 ether);
        assertEq(income.balanceOf(bob), 0.1 ether);
        // Income contract itself still holds 50% of the tokens
        assertEq(holders.withdrawableDividendOf(address(income)), 0.5 ether);
    }

    function test_Transfer_WithdrawsEthToRecipientAndReducesBalance() public {
        // Alice should accrue dividends
        _moveHolderTokensFromIncome(alice, 25 ether); // 25%
        _sendEthToHolders(address(0xD2), 2 ether);   // 2 ETH income

        // Alice has 0.5 ETH withdrawable (25% of 2)
        assertEq(income.balanceOf(alice), 0.5 ether);

        // Alice transfers 0.3 ETH to Bob via FeemakerIncome.transfer
        vm.prank(alice);
        bool ok = income.transfer(bob, 0.3 ether);
        assertTrue(ok);

        // Bob received ETH, Alice's withdrawable decreased
        assertEq(bob.balance, 0.3 ether);
        assertEq(income.balanceOf(alice), 0.2 ether);
    }

    function test_Transfer_RevertOnZeroRecipient() public {
        _moveHolderTokensFromIncome(alice, 10 ether);
        _sendEthToHolders(address(0xD3), 1 ether); // Alice has 0.1 ETH

        vm.prank(alice);
        vm.expectRevert(bytes("zero recipient"));
        income.transfer(address(0), 0.05 ether);
    }

    function test_ApproveAndAllowanceAndTransferFrom() public {
        // Set up dividends for Alice
        _moveHolderTokensFromIncome(alice, 20 ether); // 20%
        _sendEthToHolders(address(0xD4), 5 ether);    // 5 ETH total
        // Alice withdrawable: 1.0 ETH
        assertEq(income.balanceOf(alice), 1 ether);

        // Alice approves Charlie to spend 0.7 ETH of her withdrawable balance
        vm.prank(alice);
        assertTrue(income.approve(charlie, 0.7 ether));
        assertEq(income.allowance(alice, charlie), 0.7 ether);

        // Charlie pulls 0.6 ETH from Alice to Bob via transferFrom
        vm.prank(charlie);
        assertTrue(income.transferFrom(alice, bob, 0.6 ether));
        assertEq(bob.balance, 0.6 ether);
        // Allowance reduced
        assertEq(income.allowance(alice, charlie), 0.1 ether);
        // Withdrawable reduced for Alice
        assertEq(income.balanceOf(alice), 0.4 ether);
    }

    function test_TransferFrom_RevertOnInsufficientAllowance() public {
        _moveHolderTokensFromIncome(alice, 30 ether); // 30%
        _sendEthToHolders(address(0xD5), 1 ether);    // Alice has 0.3 ETH

        // No approval given to Charlie
        vm.prank(charlie);
        vm.expectRevert(bytes("insufficient allowance"));
        income.transferFrom(alice, bob, 0.1 ether);
    }
}


