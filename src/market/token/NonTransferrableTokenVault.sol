// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {Math} from "@src/market/libraries/Math.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

/// @title NonTransferrableTokenVault
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice An ERC-20 that is not transferrable from outside of the protocol.
///         This vault holds Aave's aTokens and ERC4626 tokens on behalf of users and mints
///           a rebasing ERC20 deposit token to users representing their underlying token amount.
/// @dev This contract was upgraded from NonTransferrableScaledTokenV1_5 in v1.8
///      By default, underlying tokens are deposited into the Aave pool, unless the user has set a vault.
///      vaults are whitelisted, and are assumed to be standard ERC4626 tokens.
///      Vaults with features such as pause, fee on transfer, and asynchronous share minting/burning are not supported.
///      The `approxTotalAssets` is an approximate number because assets belong to different vaults and can grow over time
contract NonTransferrableTokenVault is IERC20Metadata, IERC20Errors, Ownable2StepUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20Metadata;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS 
    //////////////////////////////////////////////////////////////*/

    IERC4626 public constant DEFAULT_VAULT = IERC4626(address(0));

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    // v1.5
    ISizeFactory public sizeFactory;
    IPool public aavePool;
    IERC20Metadata public underlyingToken;

    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public scaledTotalSupply;
    mapping(address user => uint256 scaledBalance) public scaledBalanceOf;

    // v1.8
    mapping(address user => IERC4626 vault) public vaultOf;
    mapping(address user => uint256 shares) public sharesOf;
    uint256 public approxTotalAssets;
    mapping(IERC4626 vault => bool whitelisted) public vaultWhitelisted;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultSet(address indexed user, IERC4626 indexed previousVault, IERC4626 indexed newVault);
    event VaultWhitelisted(IERC4626 indexed vault, bool indexed previousWhitelisted, bool indexed newWhitelisted);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyMarket();
    error InsufficientTotalAssets(address vault, uint256 totalAssets, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyMarket() {
        if (!sizeFactory.isMarket(msg.sender)) {
            revert Errors.UNAUTHORIZED(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR/INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        ISizeFactory sizeFactory_,
        IPool aavePool_,
        IERC20Metadata underlyingToken_,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external initializer {
        __Ownable_init(owner_);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        if (
            address(sizeFactory_) == address(0) || address(aavePool_) == address(0)
                || address(underlyingToken_) == address(0)
        ) {
            revert Errors.NULL_ADDRESS();
        }

        sizeFactory = sizeFactory_;

        aavePool = aavePool_;
        underlyingToken = underlyingToken_;

        name = name_;
        symbol = symbol_;
        decimals = decimals_;

        // v1.8
        _setVaultWhitelisted(DEFAULT_VAULT, true);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function reinitialize(string memory name_, string memory symbol_) external onlyOwner reinitializer(1_08_00) {
        name = name_;
        symbol = symbol_;

        // v1.8
        _setVaultWhitelisted(DEFAULT_VAULT, true);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setVaultWhitelisted(IERC4626 vault, bool whitelisted) external onlyOwner {
        _setVaultWhitelisted(vault, whitelisted);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20
    function transferFrom(address from, address to, uint256 value) public virtual onlyMarket returns (bool) {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        // slither-disable-next-line unused-return
        _transferFrom(from, to, value, vaultOf[from], vaultOf[to]);

        emit Transfer(from, to, value);
        return true;
    }

    /// @inheritdoc IERC20
    function transfer(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    /// @inheritdoc IERC20
    function allowance(address, address spender) public view virtual override returns (uint256) {
        return sizeFactory.isMarket(spender) ? type(uint256).max : 0;
    }

    /// @inheritdoc IERC20
    function approve(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view returns (uint256) {
        IERC4626 vault = vaultOf[account];
        if (vault == DEFAULT_VAULT) {
            return _unscale(scaledBalanceOf[account]);
        } else {
            return vault.convertToAssets(sharesOf[account]);
        }
    }

    /// @inheritdoc IERC20
    /// @notice Returns the approximate total supply of underlying tokens by adding
    ///           the approximate number of assets in all ERC4626 vaults and the unscaled total supply on Aave
    /// @dev This number should be used for informational purposes only
    function totalSupply() public view returns (uint256) {
        return _unscale(scaledTotalSupply) + approxTotalAssets;
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the vault
    /// @dev This function is only callable by the market
    ///      Setting the vault to `address(0)` will use the default variable pool
    ///      Setting the vault to a different address will withdraw all the user's assets
    ///        from the previous vault and deposit them into the new vault
    ///      Reverts if the vault asset is not the same as the NonTransferrableTokenVault's underlying token
    function setVault(address user, IERC4626 vault) external onlyMarket {
        if (user == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (vault != DEFAULT_VAULT && vault.asset() != address(underlyingToken)) {
            revert Errors.INVALID_VAULT(address(vault));
        }
        if (vaultWhitelisted[vault] && vaultOf[user] != vault) {
            _transferFrom(user, user, balanceOf(user), vaultOf[user], vault);

            emit VaultSet(user, vaultOf[user], vault);
            vaultOf[user] = vault;
        }
    }

    /// @notice Deposit underlying tokens into the variable pool and mint scaled tokens
    /// @dev The actual deposited amount can be lower than the input amount based on the vault deposit and rounding logic
    function deposit(address from, address to, uint256 amount)
        external
        onlyMarket
        returns (uint256 assets, uint256 shares)
    {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

        (assets, shares) = _deposit(from, to, amount, vaultOf[to]);

        emit Transfer(address(0), to, assets);
    }

    /// @notice Withdraw underlying tokens from the variable pool and burn scaled tokens
    /// @dev The actual withdrawn amount can be lower than the input amount based on the vault withdraw and rounding logic.
    ///      If `amount` is equal to the user's `balanceOf`, a full withdrawal is performed
    ///        and the user's shares in the vault are reset to 0 to avoid leaving behind dust.
    ///        This is important because small residual share amounts (due to rounding) can lead to
    ///        inconsistencies when the user changes vaults. For example, if the user switches to a new
    ///        vault but still holds a dust amount of shares in the previous one, the underlying tokens
    ///        held by the new vault may not accurately reflect the current vault assignment, leading to
    ///        misattribution of assets. The dust is sent to the owner.
    ///        See https://slowmist.medium.com/slowmist-aave-v2-security-audit-checklist-0d9ef442436b#5aed
    function withdraw(address from, address to, uint256 amount)
        external
        onlyMarket
        returns (uint256 assets, uint256 shares)
    {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        (assets, shares) = _withdraw(from, to, amount, vaultOf[from]);

        emit Transfer(from, address(0), assets);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current liquidity index of the variable pool
    /// @return The current liquidity index of the variable pool
    function liquidityIndex() public view returns (uint256) {
        return aavePool.getReserveNormalizedIncome(address(underlyingToken));
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits underlying tokens into an ERC4626 vault or the Aave pool
    function _deposit(address from, address to, uint256 amount, IERC4626 vault)
        private
        returns (uint256 assets, uint256 shares)
    {
        if (vault == DEFAULT_VAULT) {
            (assets, shares) = _depositToAave(from, to, amount);
        } else {
            (assets, shares) = _depositToVault(from, to, amount, vault);
        }
    }

    /// @notice Withdraws underlying tokens from an ERC4626 vault or the Aave pool
    function _withdraw(address from, address to, uint256 amount, IERC4626 vault)
        private
        returns (uint256 assets, uint256 shares)
    {
        bool fullWithdraw = amount == balanceOf(from);
        if (vault == DEFAULT_VAULT) {
            (assets, shares) = _withdrawFromAave(from, to, amount, fullWithdraw);
        } else {
            (assets, shares) = _withdrawFromVault(from, to, amount, fullWithdraw, vault);
        }
    }

    /// @notice Transfers underlying tokens between users (ERC4626 vaults or Aave)
    /// @dev If the amount is 0, short circuit, as some ERC4626 vaults revert on 0 deposit/withdraw/transfer
    function _transferFrom(address from, address to, uint256 value, IERC4626 vaultFrom, IERC4626 vaultTo)
        private
        returns (uint256 assets, uint256 shares)
    {
        // slither-disable-next-line incorrect-equality
        if (value == 0) return (0, 0);

        if (vaultFrom == vaultTo) {
            if (vaultFrom == DEFAULT_VAULT) {
                (assets, shares) = _transferFromAaveSame(from, to, value);
            } else {
                (assets, shares) = _transferFromVaultSame(from, to, value, vaultFrom);
            }
        } else {
            // slither-disable-next-line unused-return
            (assets,) = _withdraw(from, address(this), value, vaultFrom);
            // slither-disable-next-line write-after-write
            (assets, shares) = _deposit(address(this), to, assets, vaultTo);
        }
    }

    /// @notice Deposits underlying tokens into an ERC4626 vault
    // slither-disable-next-line reentrancy-benign
    function _depositToVault(address, address to, uint256 amount, IERC4626 vault)
        private
        returns (uint256 assets, uint256 shares)
    {
        underlyingToken.forceApprove(address(vault), amount);

        uint256 sharesBefore = vault.balanceOf(address(this));

        // slither-disable-next-line unused-return
        vault.deposit(amount, address(this));

        shares = vault.balanceOf(address(this)) - sharesBefore;
        assets = vault.convertToAssets(shares);

        sharesOf[to] += shares;
        approxTotalAssets += assets;
    }

    /// @notice Deposits underlying tokens into the Aave pool
    // slither-disable-next-line reentrancy-benign
    function _depositToAave(address, address to, uint256 amount) private returns (uint256 assets, uint256 shares) {
        IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);

        uint256 sharesBefore = aToken.scaledBalanceOf(address(this));

        underlyingToken.forceApprove(address(aavePool), amount);
        aavePool.supply(address(underlyingToken), amount, address(this), 0);

        shares = aToken.scaledBalanceOf(address(this)) - sharesBefore;
        assets = _unscale(shares);

        scaledTotalSupply += shares;
        scaledBalanceOf[to] += shares;
    }

    /// @notice Withdraws underlying tokens from an ERC4626 vault
    // slither-disable-next-line reentrancy-benign
    function _withdrawFromVault(address from, address to, uint256 amount, bool fullWithdraw, IERC4626 vault)
        private
        returns (uint256 assets, uint256 shares)
    {
        uint256 sharesBefore = vault.balanceOf(address(this));
        uint256 assetsBefore = underlyingToken.balanceOf(address(this));

        // slither-disable-next-line unused-return
        vault.withdraw(amount, address(this), address(this));

        shares = sharesBefore - vault.balanceOf(address(this));
        assets = underlyingToken.balanceOf(address(this)) - assetsBefore;

        underlyingToken.safeTransfer(to, assets);

        if (fullWithdraw) {
            uint256 dust = sharesOf[from] - shares;
            sharesOf[from] = 0;
            sharesOf[owner()] += dust;
        } else {
            sharesOf[from] -= shares;
        }

        if (approxTotalAssets > assets) {
            approxTotalAssets -= assets;
        } else {
            approxTotalAssets = 0;
        }
    }

    /// @notice Withdraws underlying tokens from the Aave pool
    // slither-disable-next-line reentrancy-benign
    function _withdrawFromAave(address from, address to, uint256 amount, bool fullWithdraw)
        private
        returns (uint256 assets, uint256 shares)
    {
        IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        // slither-disable-next-line unused-return
        aavePool.withdraw(address(underlyingToken), amount, to);

        shares = scaledBalanceBefore - aToken.scaledBalanceOf(address(this));
        assets = _unscale(shares);

        if (scaledBalanceOf[from] < shares) {
            revert ERC20InsufficientBalance(from, balanceOf(from), amount);
        }

        if (fullWithdraw) {
            uint256 dust = scaledBalanceOf[from] - shares;
            scaledBalanceOf[from] = 0;
            scaledBalanceOf[owner()] += dust;
        } else {
            scaledBalanceOf[from] -= shares;
        }
        scaledTotalSupply -= shares;
    }

    /// @notice Transfers assets between an ERC4626 vault and the same ERC4626 vault
    /// @dev The assets are converted to shares and then transferred internally
    ///      The share amount is rounded down
    function _transferFromVaultSame(address from, address to, uint256 value, IERC4626 vault)
        private
        returns (uint256 assets, uint256 shares)
    {
        if (vault.totalAssets() < value) {
            revert InsufficientTotalAssets(address(vault), vault.totalAssets(), value);
        }

        shares = vault.convertToShares(value);
        assets = value;

        if (sharesOf[from] < shares) {
            revert ERC20InsufficientBalance(from, balanceOf(from), value);
        }

        sharesOf[from] -= shares;
        sharesOf[to] += shares;
    }

    /// @notice Transfers underlying tokens between the users using Aave as their vault choice
    /// @dev The underlying tokens are converted to scaled tokens and then transferred internally
    ///      The scaled amount is rounded down
    ///      If the Aave pool has insufficient liquidity, the ERC20InsufficientTotalAssets error is thrown with DEFAULT_VAULT as the vault parameter,
    ///        even though the underlying balance is checked against the Aave pool
    function _transferFromAaveSame(address from, address to, uint256 value)
        private
        returns (uint256 assets, uint256 shares)
    {
        IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);
        if (underlyingToken.balanceOf(address(aToken)) < value) {
            revert InsufficientTotalAssets(address(DEFAULT_VAULT), underlyingToken.balanceOf(address(aToken)), value);
        }

        shares = Math.mulDivDown(value, WadRayMath.RAY, liquidityIndex());
        assets = value;

        if (scaledBalanceOf[from] < shares) {
            revert ERC20InsufficientBalance(from, balanceOf(from), value);
        }

        scaledBalanceOf[from] -= shares;
        scaledBalanceOf[to] += shares;
    }

    /// @notice Unscales a scaled amount
    /// @return The unscaled amount
    /// @dev The unscaled amount is the scaled amount divided by the current liquidity index
    function _unscale(uint256 scaledAmount) private view returns (uint256) {
        return Math.mulDivDown(scaledAmount, liquidityIndex(), WadRayMath.RAY);
    }

    /// @notice Sets the whitelist status of a vault
    function _setVaultWhitelisted(IERC4626 vault, bool whitelisted) private {
        emit VaultWhitelisted(vault, vaultWhitelisted[vault], whitelisted);
        vaultWhitelisted[vault] = whitelisted;
    }
}
