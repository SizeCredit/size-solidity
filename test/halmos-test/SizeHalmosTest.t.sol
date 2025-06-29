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
        usdc = new USDC(address(actors[0]));
        variablePool = IPool(address(new PoolMock()));
        sizeFactory = new SizeFactoryMock(address(actors[0]));
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
        AaveAdapter aaveAdapter = new AaveAdapter(token, variablePool, usdc);
        token.setAdapter(bytes32("AaveAdapter"), aaveAdapter);
        token.setVaultAdapter(DEFAULT_VAULT, bytes32("AaveAdapter"));

        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(token, usdc);
        token.setAdapter(bytes32("ERC4626Adapter"), erc4626Adapter);
        token.setVaultAdapter(address(vaults[0]), bytes32("ERC4626Adapter"));

        vaultSolady = IERC4626(address(new ERC4626Solady(address(usdc), "VaultSolady", "VAULTSOLADY", true, 0)));
        token.setVaultAdapter(address(vaultSolady), bytes32("ERC4626Adapter"));

        vm.stopPrank();

        vm.startPrank(address(actors[0]));
        sizeFactory.setMarket(address(actors[0]), true);
        usdc.mint(address(actors[0]), 2 * USDC_INITIAL_BALANCE);
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
        halmosHelpersSetSymbolicCallbacksDepth(0, 0);

        // Consider limited set of functions
        //halmosHelpersSetOnlyAllowedSelectors(true);
        //halmosHelpersAllowFunctionSelector(token.setVault.selector);
        //halmosHelpersAllowFunctionSelector(token.transferFrom.selector);
        //halmosHelpersAllowFunctionSelector(token.deposit.selector);
        vm.stopPrank();
    }

    function check_balanceIntegrity() external {
        settingUp();
        console.log("balances are ");
        console.log(usdc.balanceOf(address(vaults[0])));
        console.log(usdc.balanceOf(address(vaultSolady)));
        console.log(usdc.totalSupply());
        vm.stopPrank();

        //vm.startPrank(address(actors[0]));
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_balanceIntegrity");
        //token.setVault(address(actors[1]), address(vaultSolady));
        vm.stopPrank();

        /*if (token.vaultOf(address(actors[1])) == address(vaultSolady) && (token.vaultOf(address(actors[2])) == address(vaultSolady)))
        {
            console.log(usdc.totalSupply());
            assert(token.sharesOf(address(actors[1])) + token.sharesOf(address(actors[2])) <= (usdc.totalSupply()));
        }*/
        // Regular vault should be able to pay its users
        assert(token.get_all_shares(address(vaultSolady)) <= usdc.balanceOf(address(vaultSolady)));
    }
}
