// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title IPool (minimal local interface)
 * @notice Only includes the functions actually used by LidoAaveGuard.
 *         Original: aave-v3-core v1.0.0, pragma =0.8.7 (incompatible with forge-std >=0.8.13).
 */
interface IPool {
    /**
     * @notice Returns the user account data for a given address
     * @param user The address of the user
     * @return totalCollateralBase   Total collateral in base currency
     * @return totalDebtBase         Total debt in base currency
     * @return availableBorrowsBase  Available borrows in base currency
     * @return currentLiquidationThreshold Current liquidation threshold
     * @return ltv                   Loan-to-value ratio
     * @return healthFactor          Health factor (18 decimals)
     */
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    /**
     * @notice Repays a borrowed amount on a specific reserve
     * @param asset   The address of the borrowed underlying asset
     * @param amount  The amount to repay (use type(uint256).max for full debt)
     * @param rateMode Interest rate mode: 1 for Stable, 2 for Variable
     * @param onBehalfOf Address of the user whose debt will be repaid
     * @return The final amount repaid
     */
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256);

    /**
     * @notice Withdraws an amount of underlying asset from the reserve
     * @param asset  The address of the underlying asset to withdraw
     * @param amount The amount to withdraw (use type(uint256).max for full balance)
     * @param to     Address that will receive the funds
     * @return The final amount withdrawn
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}
