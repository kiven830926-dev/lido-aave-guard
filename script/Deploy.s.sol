// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import {Script, console} from "forge-std/Script.sol";
import {LidoAaveGuard} from "../src/LidoAaveGuard.sol";

/**
 * @title Deploy
 * @notice Deployment script for LidoAaveGuard contract
 * @dev Supports deployment to multiple networks via environment variables
 */
contract Deploy is Script {
    // ========================================================================
    // Deployment Configuration
    // ========================================================================

    /// @dev Contract addresses by network (for reference)
    address private constant STETH_MAINNET = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address private constant AAVE_POOL_MAINNET = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // ========================================================================
    // Main Deployment Function
    // ========================================================================

    /**
     * @notice Deploy LidoAaveGuard contract
     * @dev Reads owner address from environment variable DEPLOYER_ADDRESS
     */
    function run() external {
        // Get deployer address from environment or use default
        string memory ownerEnv = vm.envString("DEPLOYER_ADDRESS");
        address deployer;

        if (bytes(ownerEnv).length > 0) {
            deployer = vm.parseAddress(ownerEnv);
        } else {
            // Use the default signer from foundry.toml or CLI
            deployer = msg.sender;
        }

        require(deployer != address(0), "Invalid deployer address");

        // Start broadcasting transactions
        vm.startBroadcast(deployer);

        console.log("Deploying LidoAaveGuard...");
        console.log("Owner:", deployer);

        // Deploy the contract
        LidoAaveGuard guard = new LidoAaveGuard(deployer);

        console.log("LidoAaveGuard deployed to:", address(guard));
        console.log("Owner configured:", guard.owner());
        console.log("Health factor threshold:", guard.healthFactorThreshold());
        console.log("Slippage tolerance (bps):", guard.slippageToleranceBps());

        // Stop broadcasting
        vm.stopBroadcast();

        console.log("Deployment complete!");
    }

    /**
     * @notice Deploy with custom configuration
     * @param owner Address of the contract owner
     * @param threshold Health factor threshold (multiplied by 1e18)
     * @param slippageBps Slippage tolerance in basis points
     */
    function runWithConfig(
        address owner,
        uint256 threshold,
        uint256 slippageBps
    ) external {
        require(owner != address(0), "Invalid owner");
        require(threshold >= 105e16, "Threshold too low");
        require(slippageBps <= 500, "Slippage too high");

        vm.startBroadcast(owner);

        console.log("Deploying LidoAaveGuard with custom config...");
        console.log("Owner:", owner);

        LidoAaveGuard guard = new LidoAaveGuard(owner);

        // Update threshold if different from default
        if (threshold != guard.healthFactorThreshold()) {
            console.log("Updating threshold to:", threshold);
            guard.updateThreshold(threshold);
        }

        // Update slippage if different from default
        if (slippageBps != guard.slippageToleranceBps()) {
            console.log("Updating slippage to:", slippageBps);
            guard.updateSlippage(slippageBps);
        }

        vm.stopBroadcast();

        console.log("Deployment with custom config complete!");
        console.log("Contract address:", address(guard));
    }

    /**
     * @notice Verify deployment on Etherscan
     * @dev Run after deployment to verify source code on Etherscan
     */
    function verify() external {
        string memory contractAddress = vm.envString("CONTRACT_ADDRESS");

        console.log("Verifying contract at:", contractAddress);

        // Etherscan verification command (run separately)
        console.log("Run: forge verify-contract", contractAddress, "LidoAaveGuard");
    }
}
