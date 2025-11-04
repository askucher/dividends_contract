// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FeemakerHolders} from "./FeemakerHolders.sol";

contract FeemakerIncome {
    string public name = "Feemaker Income";
    string public symbol = "WETH";
    FeemakerHolders public holders;
    mapping(address => mapping(address => uint256)) public allowance;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor() {
        holders = new FeemakerHolders(100 ether);
    }

    function balanceOf(address account) public view returns (uint256) {
        return holders.withdrawableDividendOf(account);
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        return holders.withdrawDividendAsOwner(msg.sender, to, amount);
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function totalSupply() public view returns (uint256) {
        // Equal to total unclaimed dividends held by the holders contract
        return address(holders).balance;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "insufficient allowance");
        unchecked {
            allowance[from][msg.sender] = allowed - amount;
        }
        return holders.withdrawDividendAsOwner(from, to, amount);
    }
}
