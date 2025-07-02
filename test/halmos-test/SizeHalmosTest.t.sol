// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import "halmos-helpers-lib/HalmosHelpers.sol";

import "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {AaveAdapter} from "@src/market/token/adapters/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {MockERC4626 as ERC4626Solady} from "@solady/test/utils/mocks/MockERC4626.sol";

import "@test/mocks/NonTransferrableRebasingTokenVaultPseudoCopy.sol";
import "@test/mocks/PoolMock.sol";
import "@test/mocks/USDC.sol";
import {SizeFactoryMock} from "@test/mocks/SizeFactoryMock.sol";

contract SizeHalmosTest is Test, HalmosHelpers {
    uint256 private constant USDC_INITIAL_BALANCE = 1_000_000e6;

    NonTransferrableRebasingTokenVaultPseudoCopy private token;
    USDC private usdc;
    IPool private variablePool;
    SizeFactoryMock private sizeFactory;
    IERC4626 internal vaultSolady;
    AaveAdapter private aaveAdapter;
    ERC4626Adapter private erc4626Adapter;

    SymbolicActor[] vaults;
    SymbolicActor[] actors;
    
    address deployer = address(0xcafe0000);
    constructor() {
    }

    function settingUp() internal {
        // Creating actors part
        vm.startPrank(getConfigurer());
        halmosHelpersInitialize(); // Initialize HalmosHelpers stuff
        /*
        * Initialize 2 Actors
        * actors[0] is owner for SizeFactoryMock and USDC
        * actors[1] is a regular user
        * actors[2] is a regular user
        */
        actors = halmosHelpersGetSymbolicActorArray(3);
        /* vault can have any implementation. Therefore we use a symbolic handler as a vault */
        vaults = halmosHelpersGetSymbolicActorArray(1);
        vm.stopPrank();

        // Setup part
        vm.startPrank(deployer);
        usdc = new USDC(deployer);
        usdc.mint(address(actors[0]), 2 * USDC_INITIAL_BALANCE);
        variablePool = IPool(address(new PoolMock()));
        sizeFactory = new SizeFactoryMock(deployer);
        sizeFactory.setMarket(address(actors[0]), true);
        token = new NonTransferrableRebasingTokenVaultPseudoCopy();
        token.initialize(
            ISizeFactory(address(sizeFactory)),
            variablePool,
            usdc,
            address(deployer),
            string.concat("Size ", usdc.name(), " Vault"),
            string.concat("sv", usdc.symbol()),
            usdc.decimals()
        );
        aaveAdapter = new AaveAdapter(token, variablePool, usdc);
        token.setAdapter(bytes32("AaveAdapter"), aaveAdapter);
        token.setVaultAdapter(DEFAULT_VAULT, bytes32("AaveAdapter"));

        erc4626Adapter = new ERC4626Adapter(token, usdc);
        token.setAdapter(bytes32("ERC4626Adapter"), erc4626Adapter);
        token.setVaultAdapter(address(vaults[0]), bytes32("ERC4626Adapter"));

        vaultSolady = IERC4626(address(new ERC4626Solady(address(usdc), "VaultSolady", "VAULTSOLADY", true, 0)));
        token.setVaultAdapter(address(vaultSolady), bytes32("ERC4626Adapter"));

        vm.stopPrank();

        vm.startPrank(address(actors[0]));
        usdc.approve(address(token), 2 * USDC_INITIAL_BALANCE);
        token.setVault(address(actors[1]), address(vaults[0]));
        token.setVault(address(actors[2]), address(vaultSolady));
        token.deposit(address(actors[1]), USDC_INITIAL_BALANCE);
        token.deposit(address(actors[2]), USDC_INITIAL_BALANCE);
        vm.stopPrank();

        // Symbolic implementation of vault can "forget" to take approved assets
        vm.prank(address(vaults[0]));
        usdc.transferFrom(address(erc4626Adapter), address(vaults[0]), USDC_INITIAL_BALANCE);

        // Symbolic analysis configuration part
        vm.startPrank(getConfigurer());
        halmosHelpersRegisterTargetAddress(address(token), "NonTransferrableRebasingTokenVaultPseudoCopy");

        // Don't consider possible reentrancy
        //halmosHelpersSetSymbolicCallbacksDepth(0, 0);

        // Consider limited set of functions
        //halmosHelpersSetOnlyAllowedSelectors(true);
        //halmosHelpersAllowFunctionSelector(token.setVault.selector);
        //halmosHelpersAllowFunctionSelector(token.transferFrom.selector);
        //halmosHelpersAllowFunctionSelector(token.deposit.selector);
        vm.stopPrank();
    }

    function check_simplifiedBalanceIntegrity() external {
        settingUp();

        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_balanceIntegrity");
        vm.stopPrank();

        assert(token.getAllShares(address(vaultSolady)) <= usdc.balanceOf(address(vaultSolady)));
    }

    /// @custom:halmos --loop 256
    function check_fullBalanceIntegrity() external {
        settingUp();
        vm.startPrank(getConfigurer());

        // Avoid calling the same function symbolically
        // TODO: Decide if we should use this option
        halmosHelpersSetNoDuplicateCalls(true);

        // Consider callbacks recursion depth up to 2
        halmosHelpersSetSymbolicCallbacksDepth(2, 2);
        // Symbolic actors and vault will execute 2 symbolic txs
        // inside the fallback
        for (uint i = 0; i < actors.length; i++) {
            actors[i].setSymbolicFallbackTxsNumber(2);
            actors[i].setSymbolicReceiveTxsNumber(2);
        }
        vaults[0].setSymbolicFallbackTxsNumber(2);
        vaults[0].setSymbolicReceiveTxsNumber(2);
        // Register all targets to symbolic execution
        halmosHelpersRegisterTargetAddress(address(usdc), "USDC");
        halmosHelpersRegisterTargetAddress(address(variablePool), "IPool");
        halmosHelpersRegisterTargetAddress(address(sizeFactory), "SizeFactoryMock");
        halmosHelpersRegisterTargetAddress(address(aaveAdapter), "AaveAdapter");
        halmosHelpersRegisterTargetAddress(address(erc4626Adapter), "ERC4626Adapter");
        halmosHelpersRegisterTargetAddress(address(vaultSolady), "IERC4626");
        halmosHelpersRegisterTargetAddress(address(vaults[0]), "SymbolicActor");
        vm.stopPrank();

        // Execute targets symbolically, depth is 2
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_balanceIntegrity_1");
        vm.stopPrank();
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_balanceIntegrity_2");
        vm.stopPrank();

        assert(token.getAllShares(address(vaultSolady)) <= usdc.balanceOf(address(vaultSolady)));
    }
}
