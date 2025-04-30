// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {AaveAdapter} from "@src/market/token/libraries/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/libraries/ERC4626Adapter.sol";

struct NTRTVStorage {
    // v1.5
    ISizeFactory sizeFactory;
    IPool aavePool;
    IERC20Metadata underlyingToken;
    string name;
    string symbol;
    uint8 decimals;
    uint256 scaledTotalSupply;
    mapping(address user => uint256 scaledBalance) scaledBalanceOf;
    // v1.8
    mapping(address user => address vault) vaultOf;
    mapping(address user => uint256 shares) sharesOf;
    mapping(address vault => uint256 dust) vaultDust;
    EnumerableMap.AddressToUintMap vaultToAdapterMap;
}

address constant DEFAULT_VAULT = address(0);

/// @title NonTransferrableRebasingTokenVault
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A non-transferrable rebasing ERC-20 token vault
///         This token vault deposits underlying tokens into Aave or ERC4626 vaults on behalf of users
///           and mints scaled tokens or shares to users representing their underlying token amount.
/// @dev This contract was upgraded from NonTransferrableScaledTokenV1_5 in v1.8
///      By default, underlying tokens are deposited into the Aave pool, unless the user has set a ERC4626 vault.
///      Vaults are whitelisted, and are assumed to be standard ERC4626 tokens.
///      Vaults with features such as pause, fee on transfer, and asynchronous share minting/burning are not supported.
abstract contract NonTransferrableRebasingTokenVaultBase {
    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    NTRTVStorage internal s;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultSet(address indexed user, address indexed previousVault, address indexed newVault);
    event VaultAdapterSet(address indexed vault, uint256 indexed adapter);
    event VaultRemoved(address indexed vault);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyMarket();
    error InsufficientTotalAssets(address vault, uint256 totalAssets, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyMarket() {
        if (!s.sizeFactory.isMarket(msg.sender)) {
            revert Errors.UNAUTHORIZED(msg.sender);
        }
        _;
    }
}
