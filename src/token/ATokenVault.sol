    // SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math} from "@src/libraries/Math.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {Errors} from "@src/libraries/Errors.sol";

/// @title ATokenVault
/// @notice A token vault that accepts underlying token deposits, attempts to supply/withdraw on a Variable Pool to get aTokens, and handles reverts
contract ATokenVault is NonTransferrableToken {
    using SafeERC20 for IERC20Metadata;

    mapping(address => uint256) internal _scaledBalances;

    event TransferScaled(address indexed from, address indexed to, uint256 value);

    IPool public immutable variablePool;
    IAToken public immutable aToken;
    IERC20Metadata public immutable underlyingToken;

    constructor(
        IPool variablePool_,
        address underlyingToken_,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) NonTransferrableToken(owner_, name_, symbol_, decimals_) {
        if (address(variablePool_) == address(0) || address(underlyingToken_) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        variablePool = variablePool_;
        underlyingToken = IERC20Metadata(underlyingToken_);
        aToken = IAToken(variablePool_.getReserveData(address(underlyingToken_)).aTokenAddress);
    }

    /// @notice Mints tokens to the recipient
    ///         Attempts to supply on the Variable Pool. If it fails, keeps the underlying tokens in the contract.
    /// @param to The recipient of the minted tokens
    /// @param value The amount of tokens to mint
    function mint(address to, uint256 value) external override onlyOwner {
        underlyingToken.safeTransferFrom(msg.sender, address(this), value);

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));
        uint256 scaledValue = 0;

        underlyingToken.forceApprove(address(variablePool), value);
        try variablePool.supply(address(underlyingToken), value, address(this), 0) {
            scaledValue = aToken.scaledBalanceOf(address(this)) - scaledBalanceBefore;
            value = 0;
        } catch {}
        underlyingToken.forceApprove(address(variablePool), 0);

        _mintScaled(to, scaledValue);
        _mint(to, value);
    }

    /// @notice Burns tokens from the account
    ///         Attempts to withdraw from the Variable Pool. If it fails, attempts to transfer underlying tokens from this contract.
    /// @param from The account to burn tokens from
    /// @param value The amount of tokens to burn
    function burn(address from, uint256 value) external override onlyOwner {
        if (balanceOf(from) < value) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(from, balanceOf(from), value);
        }

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));
        uint256 scaledValue = 0;

        // slither-disable-next-line unused-return
        try variablePool.withdraw(address(underlyingToken), value, msg.sender) {
            scaledValue = scaledBalanceBefore - aToken.scaledBalanceOf(address(this));
            (value, scaledValue) = _capToScaledBalance(from, value, scaledValue);
        } catch {}

        _burnScaled(from, scaledValue);
        _burn(from, value);

        underlyingToken.transfer(msg.sender, value);
    }

    /// @notice Transfers tokens from one account to another
    ///         Attempts to transfer Variable Pool scaled token balances first, and underlying tokens second
    /// @param from The account to transfer tokens from
    /// @param to The account to transfer tokens to
    /// @param value The amount of tokens to transfer
    /// @return True if the transfer was successful
    function transferFrom(address from, address to, uint256 value) public override onlyOwner returns (bool) {
        if (balanceOf(from) < value) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(from, balanceOf(from), value);
        }

        uint256 scaledValue = _scaledValue(value);

        (value, scaledValue) = _capToScaledBalance(from, value, scaledValue);

        _transferScaled(from, to, scaledValue);
        _transfer(from, to, value);

        return true;
    }

    function rebalance(address account, uint256 value, bool fromUnderlyingTokenToAToken) external onlyOwner {
        if (balanceOf(account) < value) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(account, balanceOf(account), value);
        }

        uint256 scaledValue = _scaledValue(value);

        if (fromUnderlyingTokenToAToken) {
            (value, scaledValue) = _capToUnderlyingBalance(account, value, scaledValue);
            _burn(account, value);
            _mintScaled(account, scaledValue);
        } else {
            (value, scaledValue) = _capToScaledBalance(account, value, scaledValue);
            _burnScaled(account, scaledValue);
            _mint(account, value);
        }
    }

    function underlyingTokenBalanceOf(address account) public view returns (uint256) {
        return super.balanceOf(account);
    }

    function aTokenBalanceOf(address account) public view returns (uint256) {
        return Math.mulDivDown(_scaledBalances[account], liquidityIndex(), WadRayMath.RAY);
    }

    /// @notice Returns the total balance of an account, including both underlying and aToken balances
    /// @param account The account to check the balance of
    /// @return The total balance of the account
    function balanceOf(address account) public view override returns (uint256) {
        return underlyingTokenBalanceOf(account) + aTokenBalanceOf(account);
    }

    function underlyingTokenTotalSupply() public view returns (uint256) {
        return super.balanceOf(address(this));
    }

    function aTokenTotalSupply() public view returns (uint256) {
        return aToken.scaledBalanceOf(address(this));
    }

    /// @notice Returns the total supply of the token, including both underlying aToken balances
    /// @return The total supply of the token
    function totalSupply() public view override returns (uint256) {
        return underlyingTokenTotalSupply() + aTokenTotalSupply();
    }

    function liquidityIndex() public view returns (uint256) {
        return variablePool.getReserveNormalizedIncome(address(underlyingToken));
    }

    function _scaledValue(uint256 value) internal view returns (uint256) {
        return Math.mulDivDown(value, WadRayMath.RAY, liquidityIndex());
    }

    /// @notice Cap the scaledValue to the scaled balance of the account, and updates the value accordingly
    function _capToScaledBalance(address from_, uint256 value_, uint256 scaledValue_)
        internal
        view
        returns (uint256 value, uint256 scaledValue)
    {
        if (_scaledBalances[from_] < scaledValue) {
            value = value_ - Math.mulDivDown(_scaledBalances[from_], WadRayMath.RAY, scaledValue_);
            scaledValue = _scaledBalances[from_];
        } else {
            value = 0;
            scaledValue = scaledValue_;
        }
    }

    function _capToUnderlyingBalance(address from_, uint256 value_, uint256 scaledValue_)
        internal
        view
        returns (uint256 value, uint256 scaledValue)
    {
        uint256 underlyingBalance_ = underlyingTokenBalanceOf(from_);
        if (underlyingBalance_ < value_) {
            scaledValue = scaledValue_ - Math.mulDivDown(underlyingBalance_, WadRayMath.RAY, value_);
            value = underlyingBalance_;
        } else {
            scaledValue = 0;
            value = value_;
        }
    }

    /// @notice Mint scaled tokens to an account
    function _mintScaled(address to, uint256 scaledValue) internal {
        _scaledBalances[to] += scaledValue;
        emit TransferScaled(address(0), to, scaledValue);
    }

    /// @notice Burn scaled tokens from an account
    function _burnScaled(address from, uint256 scaledValue) internal {
        _scaledBalances[from] -= scaledValue;
        emit TransferScaled(from, address(0), scaledValue);
    }

    /// @notice Transfer scaled tokens from one account to another
    function _transferScaled(address from, address to, uint256 scaledValue) internal {
        _scaledBalances[from] -= scaledValue;
        _scaledBalances[to] += scaledValue;
        emit TransferScaled(from, to, scaledValue);
    }
}
