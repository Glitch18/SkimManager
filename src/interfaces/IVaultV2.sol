// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Minimal interface for VaultV2 from morpho-org/vault-v2
interface IVaultV2 {
    /// @dev Parent vault's asset
    function asset() external view returns (address);
}
