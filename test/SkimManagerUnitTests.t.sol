// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * Test cases:
 *
 * - Other addresses try to call adapter.skim()
 * - Call skimManager.skimAdapter() with no rewards present in Adapter
 * - Call skimManager.skimAdapter() with rewards present in Adapter and receive successfully
 * - Call skimManager.skimAdapter() with rewards present in Adapter and receive successfully but parent token is the same as reward token
 */
