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

/// @title WrappedAToken
/// @notice An ERC-20 that wraps an AToken and handles supply/withdraw reverts from the Variable Pool
/// @dev The contract owner (e.g. the Size contract) can still mint, burn, and transfer tokens
contract WrappedAToken is NonTransferrableToken {
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

        uint256 scaledValue = Math.mulDivDown(value, WadRayMath.RAY, liquidityIndex());

        (value, scaledValue) = _capToScaledBalance(from, value, scaledValue);

        _transferScaled(from, to, scaledValue);
        _transfer(from, to, value);

        return true;
    }

    /// @notice Returns the balance of an account
    function unscaledBalanceOf(address account) public view returns (uint256) {
        return Math.mulDivDown(_scaledBalances[account], liquidityIndex(), WadRayMath.RAY);
    }

    /// @notice Returns the total balance of an account, including both underlying and aToken balances
    /// @param account The account to check the balance of
    /// @return The total balance of the account
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account) + unscaledBalanceOf(account);
    }

    /// @notice Returns the total supply of the token, including aToken balances
    /// @return The total supply of the token
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply() + aToken.balanceOf(address(this));
    }

    function liquidityIndex() public view returns (uint256) {
        return variablePool.getReserveNormalizedIncome(address(underlyingToken));
    }

    /// @notice Cap the scaledValue to the scaled balance of the account, and updates the value accordingly
    function _capToScaledBalance(address _from, uint256 _value, uint256 _scaledValue)
        internal
        view
        returns (uint256 value, uint256 scaledValue)
    {
        if (_scaledBalances[_from] < scaledValue) {
            value = _value - Math.mulDivDown(_scaledBalances[_from], WadRayMath.RAY, _scaledValue);
            scaledValue = _scaledBalances[_from];
        } else {
            value = 0;
            scaledValue = _scaledValue;
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
