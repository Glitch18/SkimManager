// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAdapter} from "./interfaces/IAdapter.sol";
import {ISwapper} from "./interfaces/ISwapper.sol";
import {IMerklDistributor} from "./interfaces/IMerklDistributor.sol";
import {IVaultV2} from "./interfaces/IVaultV2.sol";

/**
 * @title SkimManager
 * @notice Contract used to skim rewards from adapters and reinvest into parent vaults
 * @dev This contract can also be used to claim rewards for an adapter from MerklDistributor
 */
contract SkimManager is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -------- Roles --------
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // -------- Errors --------
    error InvalidAddress();
    error NothingToSkim();
    error InvalidArrayLengths();
    error InvalidAmount();
    error NotEnoughProceeds();

    // -------- Config --------
    ISwapper public swapper; // Box swapper
    IMerklDistributor public distributor; // Merkl Rewards Distributor

    // -------- Events --------
    event SwapperSet(address indexed swapper);
    event DistributorSet(address indexed distributor);
    event RewardsClaimed(address indexed user, address indexed token, uint256 amount);
    event RewardsSkimmed(
        address indexed adapter,
        address indexed token,
        address indexed parentToken,
        uint256 rewardTokenBalance,
        uint256 parentTokenBalance
    );
    event ProceedsSent(address indexed parentVault, address indexed parentToken, uint256 amount);

    // -------- Constructor --------
    constructor(address admin, address _swapper, address _merklDistributor) {
        if (admin == address(0) || _swapper == address(0) || _merklDistributor == address(0)) {
            revert InvalidAddress();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        swapper = ISwapper(_swapper);
        distributor = IMerklDistributor(_merklDistributor);

        emit SwapperSet(_swapper);
        emit DistributorSet(_merklDistributor);
    }

    // -------- Admin Config --------

    /// @notice Set the swapper contract.
    function setSwapper(address _swapper) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_swapper == address(0)) revert InvalidAddress();
        swapper = ISwapper(_swapper);
        emit SwapperSet(_swapper);
    }

    /// @notice Set the Merkl distributor contract.
    function setDistributor(address _merklDistributor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_merklDistributor == address(0)) revert InvalidAddress();
        distributor = IMerklDistributor(_merklDistributor);
        emit DistributorSet(_merklDistributor);
    }

    /// @notice Rescue any ERC20 tokens to a safe address (admin-only).
    function rescue(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        IERC20(token).safeTransfer(to, amount);
    }

    // -------- View Functions --------

    /// @notice Get the amount of tokens that can be skimmed from an adapter.
    function getSkimmableAmount(address adapter, address token) external view returns (uint256) {
        if (adapter == address(0) || token == address(0)) revert InvalidAddress();
        IAdapter vaultAdapter = IAdapter(adapter);
        return IERC20(token).balanceOf(address(vaultAdapter));
    }

    // -------- Core Functions --------

    /// @notice Skim rewards from an adapter , convert to parent vault asset and send to parent vault.
    /// @param adapter The address of the adapter.
    /// @param token The address of the token to skim.
    /// @param swapData The data to pass to the swapper.
    /// @param minProceeds The minimum amount of proceeds to send to the parent vault.
    function skimAdapter(address adapter, address token, bytes calldata swapData, uint256 minProceeds)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
    {
        if (adapter == address(0) || token == address(0)) revert InvalidAddress();

        // Get Adapter
        IAdapter vaultAdapter = IAdapter(adapter);

        // Call adapter.skim(token) to receive tokens
        uint256 tokenBalanceBefore = IERC20(token).balanceOf(address(this));
        vaultAdapter.skim(token);

        // Check accrued rewards of Adapter
        // Use difference to avoid front-running
        uint256 rewardsIn = IERC20(token).balanceOf(address(this)) - tokenBalanceBefore;
        if (rewardsIn == 0) {
            revert NothingToSkim();
        }

        // Get parent vault
        IVaultV2 parentVault = IVaultV2(vaultAdapter.parentVault());
        IERC20 parentToken = IERC20(parentVault.asset());

        uint256 proceeds;
        if (address(parentToken) == address(token)) {
            // If parent token is the same as reward token, we can skip the swap
            proceeds = rewardsIn;
        } else {
            // Set exact allowance for Swapper
            IERC20(token).forceApprove(address(swapper), rewardsIn);

            // Sell using Swapper
            uint256 balanceBefore = parentToken.balanceOf(address(this));
            swapper.sell(IERC20(token), parentToken, rewardsIn, swapData);
            uint256 balanceAfter = parentToken.balanceOf(address(this));

            proceeds = balanceAfter - balanceBefore;
            if (proceeds < minProceeds || proceeds == 0) {
                revert NotEnoughProceeds();
            }
        }

        // Send results to adapter.parentVault
        parentToken.safeTransfer(address(parentVault), proceeds);
        emit RewardsSkimmed(address(vaultAdapter), token, address(parentVault), rewardsIn, proceeds);
        emit ProceedsSent(address(parentVault), address(parentToken), proceeds);
    }

    /// @notice Claim rewards from Merkl distributor.
    /// @param users The addresses of the users to claim rewards for.
    /// @param tokens The addresses of the tokens to claim rewards for.
    /// @param amounts The amounts of tokens to claim rewards for.
    /// @param proofs The proofs for the Merkl distributor.
    function claimRewards(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external onlyRole(OPERATOR_ROLE) nonReentrant {
        // Array length validation
        if (users.length != tokens.length || users.length != amounts.length || users.length != proofs.length) {
            revert InvalidArrayLengths();
        }
        if (users.length == 0) {
            revert InvalidArrayLengths();
        }

        // Claim rewards from Merkl distributor
        distributor.claim(users, tokens, amounts, proofs);

        // Emit Claim event for each user
        for (uint256 i = 0; i < users.length; i++) {
            emit RewardsClaimed(users[i], tokens[i], amounts[i]);
        }
    }
}
