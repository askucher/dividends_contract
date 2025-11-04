// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IncomeShareToken - ERC20 token that distributes ETH income proportionally to token holders.
/// @notice Each token represents a share of contract income (ETH received).
///         Dividends are claimable and not automatically sent, ensuring precise accounting on transfer.
contract FeemakerHolders {
    string public name = "FeemakerHolders";
    string public symbol = "FMH";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    /// @notice Cumulative ETH per token, scaled for precision.
    uint256 public magnifiedDividendPerShare;
    uint256 internal constant MAGNITUDE = 1e18;

    /// @notice Tracks how much income a user has already been accounted for.
    mapping(address => int256) private magnifiedDividendCorrections;
    mapping(address => uint256) private withdrawnDividends;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event DividendsDistributed(address indexed from, uint256 weiAmount);
    event DividendWithdrawn(address indexed to, uint256 weiAmount);

    constructor(uint256 initialSupply) {
        _mint(msg.sender, initialSupply);
    }

    // ======== ERC20 standard ========

    /// @notice Returns the token balance of a given `account`.
    /// @param account The address whose balance is being queried.
    /// @return The number of tokens held by `account`.
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /// @notice Returns the remaining number of tokens that `spender` is allowed to spend on behalf of `owner`.
    /// @param owner The address which owns the tokens.
    /// @param spender The address which will spend the tokens.
    /// @return The remaining allowance for `spender`.
    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @notice Approves `spender` to transfer up to `amount` tokens from the caller's account.
    /// @param spender The address authorized to spend the tokens.
    /// @param amount The maximum amount `spender` can transfer.
    /// @return True if the operation succeeded.
    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers `amount` tokens from the caller to `to`.
    /// @param to The recipient address.
    /// @param amount The number of tokens to transfer.
    /// @return True if the transfer succeeded.
    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Transfers `amount` tokens from `from` to `to` using the allowance mechanism.
    /// @dev Decreases the caller's allowance from `from` by `amount`.
    /// @param from The address to transfer tokens from.
    /// @param to The address to transfer tokens to.
    /// @param amount The number of tokens to transfer.
    /// @return True if the transfer succeeded.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount, "ERC20: insufficient allowance");
        _allowances[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    /// @dev Moves `amount` tokens from `from` to `to`, updating dividend corrections.
    /// @param from The address tokens are moved from.
    /// @param to The address tokens are moved to.
    /// @param amount The number of tokens to move.
    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "transfer to zero");
        _balances[from] -= amount;
        _balances[to] += amount;

        // Adjust dividend correction balances
        int256 magCorrection = int256(magnifiedDividendPerShare * amount);
        magnifiedDividendCorrections[from] += magCorrection;
        magnifiedDividendCorrections[to] -= magCorrection;

        emit Transfer(from, to, amount);
    }

    /// @dev Creates `amount` tokens and assigns them to `account`, updating dividend corrections.
    /// @param account The address receiving the newly minted tokens.
    /// @param amount The number of tokens to mint.
    function _mint(address account, uint256 amount) internal {
        require(account != address(0));
        totalSupply += amount;
        _balances[account] += amount;

        magnifiedDividendCorrections[account] -= int256(
            magnifiedDividendPerShare * amount
        );
        emit Transfer(address(0), account, amount);
    }

    // ======== Income logic ========

    /// @notice Receive ETH and distribute proportionally to token holders
    receive() external payable {
        distributeDividends();
    }

    /// @notice Distributes the received ETH among token holders proportionally to their balances.
    /// @dev Increases `magnifiedDividendPerShare` based on `msg.value` and `totalSupply`.
    ///      Emits {DividendsDistributed} when value is positive.
    function distributeDividends() public payable {
        require(totalSupply > 0, "no tokens");
        if (msg.value > 0) {
            magnifiedDividendPerShare += (msg.value * MAGNITUDE) / totalSupply;
            emit DividendsDistributed(msg.sender, msg.value);
        }
    }

    /// @notice Returns how much ETH an `account` can withdraw at the current moment.
    /// @param account The address to query for withdrawable dividends.
    /// @return The amount of ETH currently withdrawable by `account`.
    function withdrawableDividendOf(
        address account
    ) public view returns (uint256) {
        return accumulativeDividendOf(account) - withdrawnDividends[account];
    }

    /// @notice Returns the total accumulated dividends for `account` (withdrawn + withdrawable).
    /// @dev Uses magnified dividend math to maintain precision.
    /// @param account The address to query for accumulated dividends.
    /// @return The total accumulated ETH dividends for `account`.
    function accumulativeDividendOf(
        address account
    ) public view returns (uint256) {
        return
            uint256(
                int256(magnifiedDividendPerShare * _balances[account]) +
                    magnifiedDividendCorrections[account]
            ) / MAGNITUDE;
    }

    /// @notice Withdraws the caller's currently withdrawable dividends.
    /// @dev Updates `withdrawnDividends` and transfers ETH to the caller.
    function withdrawDividend() public {
        uint256 withdrawable = withdrawableDividendOf(msg.sender);
        if (withdrawable > 0) {
            withdrawnDividends[msg.sender] += withdrawable;
            (bool success, ) = msg.sender.call{value: withdrawable}("");
            require(success, "ETH transfer failed");
            emit DividendWithdrawn(msg.sender, withdrawable);
        }
    }
}
