// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

/// @title VaultWrapper
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
contract VaultWrapper is Ownable2StepUpgradeable, UUPSUpgradeable, ERC20Upgradeable {
    using SafeERC20 for IERC20Metadata;

    ISizeFactory public sizeFactory;
    IERC20Metadata public underlyingToken;
    mapping(address user => IERC4626 vault) public userVaults;
    ERC1155Supply public vaultToken;
    IERC4626 public defaultVault;

    event DefaultVaultSet(IERC4626 indexed previousDefaultVault, IERC4626 indexed newDefaultVault);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        ISizeFactory sizeFactory_,
        IERC20Metadata underlyingToken_,
        address owner_,
        string memory name_,
        string memory symbol_,
        string memory uri,
        IERC4626 defaultVault_
    ) external initializer {
        __Ownable_init(owner_);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        __ERC20_init(name_, symbol_);

        if (address(sizeFactory_) == address(0) || address(underlyingToken_) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        sizeFactory = sizeFactory_;
        underlyingToken = underlyingToken_;
        vaultToken = new ERC1155Supply(uri);
        _setDefaultVault(defaultVault_);
    }

    function setDefaultVault(IERC4626 defaultVault_) external onlyOwner {
        _setDefaultVault(defaultVault_);
    }

    function deposit(address, address to, uint256 amount) external onlyMarket {
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

        IERC4626 userVault = userVaults[to];

        uint256 balanceBefore = userVault.balanceOf(address(this));

        underlyingToken.forceApprove(address(userVault), amount);
        userVault.deposit(amount, to);

        uint256 shares = userVault.balanceOf(address(this)) - balanceBefore;

        vaultToken.mint(to, id(to), shares);
    }

    function withdraw(address from, address to, uint256 amount) external onlyMarket {
        IERC4626 userVault = userVaults[from];

        uint256 balanceBefore = userVault.balanceOf(address(this));

        userVault.withdraw(amount, to, address(this));

        uint256 shares = balanceBefore - userVault.balanceOf(address(this));

        vaultToken.burn(from, id(from), shares);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        // TODO
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        // TODO
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        // TODO
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        // TODO
    }

    function decimals() public view virtual override returns (uint8) {
        return underlyingToken.decimals();
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return vaultToken.balanceOf(account);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return vaultToken.totalSupply();
    }

    function id(address user) public view returns (uint256) {
        return uint256(uint160(address(userVaults[user] == IERC4626(address(0)) ? defaultVault : userVaults[user])));
    }

    function _setDefaultVault(IERC4626 defaultVault_) internal {
        emit DefaultVaultSet(defaultVault, defaultVault_);
        defaultVault = defaultVault_;
    }
}
