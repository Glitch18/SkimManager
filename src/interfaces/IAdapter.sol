// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Minimal interface for the Morpho adapter
interface IAdapter {
    /// @dev Skim the given token balance and transfer to skimRecipient
    function skim(address token) external;

    /// @dev Parent vault that allocates to this adapter
    function parentVault() external view returns (address);
}
