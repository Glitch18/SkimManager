// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Minimal Merkl Universal Rewards Distributor (URD) interface (claim only).
interface IMerklDistributor {
    /// @dev Claims rewards to each `users[i]` for `tokens[i]` with `amounts[i]` using `proofs[i]`.
    /// @notice msg.sender must be an approved operator for each user
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;
}
