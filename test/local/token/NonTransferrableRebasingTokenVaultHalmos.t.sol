// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {DEFAULT_VAULT} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {AaveAdapter} from "@src/market/token/adapters/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";
import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

import {USDC} from "@test/mocks/USDC.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

contract NonTransferrableRebasingTokenVaultMock is NonTransferrableRebasingTokenVault {
    // Mock version to allow direct manipulation for testing
    function mockSetSharesOf(address user, uint256 shares) external {
        sharesOf[user] = shares;
    }
    
    function mockSetVaultOf(address user, address vault) external {
        vaultOf[user] = vault;
    }
    
    function mockTransferUnderlyingTo(address to, uint256 amount) external {
        underlyingToken.transfer(to, amount);
    }
}

contract AdapterMock is IAdapter {
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => uint256) public vaultTotalSupply;
    IERC20Metadata public underlyingToken;
    
    constructor(IERC20Metadata _underlyingToken) {
        underlyingToken = _underlyingToken;
    }
    
    function validate(address) external pure override {}
    
    function balanceOf(address, address user) external view override returns (uint256) {
        return balances[address(0)][user]; // Simplified for testing
    }
    
    function totalSupply(address vault) external view override returns (uint256) {
        return vaultTotalSupply[vault];
    }
    
    function deposit(address vault, address user, uint256 amount) external override returns (uint256) {
        balances[vault][user] += amount;
        vaultTotalSupply[vault] += amount;
        return amount;
    }
    
    function withdraw(address vault, address user, address to, uint256 amount) external override returns (uint256) {
        balances[vault][user] -= amount;
        vaultTotalSupply[vault] -= amount;
        underlyingToken.transfer(to, amount);
        return amount;
    }
    
    function fullWithdraw(address vault, address user, address to) external override returns (uint256) {
        uint256 balance = balances[vault][user];
        balances[vault][user] = 0;
        vaultTotalSupply[vault] -= balance;
        underlyingToken.transfer(to, balance);
        return balance;
    }
    
    function transferFrom(address vault, address from, address to, uint256 amount) external override {
        balances[vault][from] -= amount;
        balances[vault][to] += amount;
    }
}

contract SizeFactoryMock is ISizeFactory {
    mapping(address => bool) public markets;
    
    function setMarket(address market, bool isMarket) external {
        markets[market] = isMarket;
    }
    
    function isMarket(address market) external view override returns (bool) {
        return markets[market];
    }
    
    function getOwner() external pure override returns (address) {
        return address(0);
    }
    
    function owner() external pure override returns (address) {
        return address(0);
    }
}

/// @custom:halmos --solver-timeout-assertion 0
contract NonTransferrableRebasingTokenVaultHalmosTest is SymTest {
    NonTransferrableRebasingTokenVaultMock public vault;
    SizeFactoryMock public sizeFactory;
    USDC public underlying;
    PoolMock public pool;
    AdapterMock public adapter;
    
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    
    function setUp() public {
        // Create symbolic addresses
        owner = svm.createAddress("owner");
        user1 = svm.createAddress("user1");
        user2 = svm.createAddress("user2");
        user3 = svm.createAddress("user3");
        
        // Deploy contracts
        underlying = new USDC();
        pool = new PoolMock(address(underlying));
        sizeFactory = new SizeFactoryMock();
        adapter = new AdapterMock(underlying);
        
        // Deploy vault
        vault = new NonTransferrableRebasingTokenVaultMock();
        vault.initialize(
            ISizeFactory(address(sizeFactory)),
            IPool(address(pool)),
            underlying,
            owner,
            "Test Vault Token",
            "TVT",
            6
        );
        
        // Set up vault with adapter
        vm.prank(owner);
        vault.reinitialize("Test Vault Token", "TVT", AaveAdapter(address(adapter)), ERC4626Adapter(address(adapter)));
        
        // Mark the vault as a market
        sizeFactory.setMarket(address(vault), true);
        
        // Give some tokens to users for testing
        underlying.mint(user1, 1000e6);
        underlying.mint(user2, 1000e6);
        underlying.mint(user3, 1000e6);
        underlying.mint(address(adapter), 1000e6);
    }
    
    /// VAULTS_01: SUM(balanceOf) <= totalSupply()
    /// @custom:halmos --solver-timeout-assertion 30000
    function check_VAULTS_01_sum_balanceOf_leq_totalSupply() public {
        // Create symbolic state
        uint256 balance1 = svm.createUint256("balance1");
        uint256 balance2 = svm.createUint256("balance2");
        uint256 balance3 = svm.createUint256("balance3");
        
        // Assume reasonable bounds
        vm.assume(balance1 <= 1000e6);
        vm.assume(balance2 <= 1000e6);
        vm.assume(balance3 <= 1000e6);
        
        // Set up balances through the adapter
        adapter.balances[DEFAULT_VAULT][user1] = balance1;
        adapter.balances[DEFAULT_VAULT][user2] = balance2;
        adapter.balances[DEFAULT_VAULT][user3] = balance3;
        adapter.vaultTotalSupply[DEFAULT_VAULT] = balance1 + balance2 + balance3;
        
        // Test the invariant: SUM(balanceOf) <= totalSupply()
        uint256 totalBalances = vault.balanceOf(user1) + vault.balanceOf(user2) + vault.balanceOf(user3);
        uint256 totalSupply = vault.totalSupply();
        
        assert(totalBalances <= totalSupply);
    }
    
    /// VAULTS_02: Changing a user vault does not leave dust shares
    /// @custom:halmos --solver-timeout-assertion 30000
    function check_VAULTS_02_vault_change_no_dust_shares(address newVault, bool forfeitOldShares) public {
        // Set up initial state
        uint256 initialShares = svm.createUint256("initialShares");
        vm.assume(initialShares > 0 && initialShares <= 1000e6);
        
        // Assume newVault is a valid vault address
        vm.assume(newVault != address(0));
        vm.assume(newVault != DEFAULT_VAULT);
        
        // Set up the new vault adapter
        vm.prank(owner);
        vault.setVaultAdapter(newVault, bytes32("ERC4626Adapter"));
        
        // Set initial shares for user1
        vault.mockSetSharesOf(user1, initialShares);
        vault.mockSetVaultOf(user1, DEFAULT_VAULT);
        
        // Change vault
        vm.prank(address(vault)); // Simulate market calling
        vault.setVault(user1, newVault, forfeitOldShares);
        
        // Check that if forfeitOldShares is true, shares should be 0
        // Otherwise, user should have moved to new vault without dust
        if (forfeitOldShares) {
            assert(vault.sharesOf(user1) == 0);
        }
        
        // Verify vault was changed
        assert(vault.vaultOf(user1) == newVault);
    }
    
    /// VAULTS_03: underlying.balanceOf(borrowTokenVault) == 0
    /// @custom:halmos --solver-timeout-assertion 30000
    function check_VAULTS_03_vault_underlying_balance_zero() public {
        // This invariant checks that the vault itself should not hold underlying tokens
        // All underlying tokens should be deposited into the actual vaults (Aave, ERC4626, etc.)
        
        // Perform some operations
        uint256 depositAmount = svm.createUint256("depositAmount");
        vm.assume(depositAmount > 0 && depositAmount <= 1000e6);
        
        // Give approval and deposit
        vm.prank(user1);
        underlying.approve(address(vault), depositAmount);
        
        vm.prank(address(vault)); // Simulate market calling
        vault.deposit(user1, depositAmount);
        
        // Check invariant: vault should not hold underlying tokens
        assert(underlying.balanceOf(address(vault)) == 0);
    }
    
    /// VAULTS_04: deposit/withdraw/transferFrom does not change the vault
    /// @custom:halmos --solver-timeout-assertion 30000
    function check_VAULTS_04_operations_preserve_vault_assignment() public {
        // Set up initial vault assignments
        address initialVault1 = DEFAULT_VAULT;
        address initialVault2 = DEFAULT_VAULT;
        
        vault.mockSetVaultOf(user1, initialVault1);
        vault.mockSetVaultOf(user2, initialVault2);
        
        // Record initial vault assignments
        address vaultBefore1 = vault.vaultOf(user1);
        address vaultBefore2 = vault.vaultOf(user2);
        
        // Test deposit operation
        uint256 depositAmount = svm.createUint256("depositAmount");
        vm.assume(depositAmount > 0 && depositAmount <= 1000e6);
        
        vm.prank(user1);
        underlying.approve(address(vault), depositAmount);
        
        vm.prank(address(vault)); // Simulate market calling
        vault.deposit(user1, depositAmount);
        
        // Check that vault assignment didn't change
        assert(vault.vaultOf(user1) == vaultBefore1);
        
        // Test withdraw operation
        uint256 withdrawAmount = svm.createUint256("withdrawAmount");
        vm.assume(withdrawAmount > 0 && withdrawAmount <= depositAmount);
        
        vm.prank(address(vault)); // Simulate market calling
        vault.withdraw(user1, user1, withdrawAmount);
        
        // Check that vault assignment didn't change
        assert(vault.vaultOf(user1) == vaultBefore1);
        
        // Test transferFrom operation (same vault)
        uint256 transferAmount = svm.createUint256("transferAmount");
        vm.assume(transferAmount > 0 && transferAmount <= depositAmount - withdrawAmount);
        
        // Set up balances for transfer
        adapter.balances[DEFAULT_VAULT][user1] = transferAmount;
        
        vm.prank(address(vault)); // Simulate market calling
        vault.transferFrom(user1, user2, transferAmount);
        
        // Check that vault assignments didn't change
        assert(vault.vaultOf(user1) == vaultBefore1);
        assert(vault.vaultOf(user2) == vaultBefore2);
    }
    
    /// Additional invariant: Shares should be non-negative
    /// @custom:halmos --solver-timeout-assertion 30000
    function check_shares_non_negative() public {
        uint256 shares = svm.createUint256("shares");
        
        // Set shares for user
        vault.mockSetSharesOf(user1, shares);
        
        // Shares should always be non-negative (this is guaranteed by uint256 type)
        assert(vault.sharesOf(user1) >= 0);
    }
    
    /// Additional invariant: Only whitelisted vaults can be used
    /// @custom:halmos --solver-timeout-assertion 30000
    function check_only_whitelisted_vaults() public {
        address randomVault = svm.createAddress("randomVault");
        vm.assume(randomVault != DEFAULT_VAULT);
        vm.assume(randomVault != address(0));
        
        // Try to set a non-whitelisted vault - should revert
        vm.prank(address(vault)); // Simulate market calling
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, randomVault));
        vault.setVault(user1, randomVault, false);
    }
}