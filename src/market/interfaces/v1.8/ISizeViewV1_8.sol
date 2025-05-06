// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title ISizeViewV1_8
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the Size v1.8 view methods
interface ISizeViewV1_8 {
    /// @notice Get the APR for a user-defined borrow offer
    /// @param borrower The address of the borrower
    /// @param tenor The tenor of the loan
    /// @return apr The APR
    function getUserDefinedBorrowOfferAPR(address borrower, uint256 tenor) external view returns (uint256);

    /// @notice Get the APR for a user-defined loan offer
    /// @param lender The address of the lender
    /// @param tenor The tenor of the loan
    /// @return apr The APR
    function getUserDefinedLoanOfferAPR(address lender, uint256 tenor) external view returns (uint256);

    /// @notice Get the APR for a borrow offer for this market
    /// @param borrower The address of the borrower
    /// @param collectionId The collection ID
    /// @param rateProvider The rate provider
    /// @param tenor The tenor of the loan
    /// @return apr The APR
    function getBorrowOfferAPR(address borrower, uint256 collectionId, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256);

    /// @notice Get the APR for a loan offer for this market
    /// @param lender The address of the lender
    /// @param collectionId The collection ID
    /// @param rateProvider The rate provider
    /// @param tenor The tenor of the loan
    /// @return apr The APR
    function getLoanOfferAPR(address lender, uint256 collectionId, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256);
}
