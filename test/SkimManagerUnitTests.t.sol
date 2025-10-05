// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {SkimManager} from "../src/SkimManager.sol";
import {DeploySkimManager} from "../script/DeploySkimManager.s.sol";
import {IAdapter} from "../src/interfaces/IAdapter.sol";
import {IMerklDistributor} from "../src/interfaces/IMerklDistributor.sol";

/**
 * Test cases:
 *
 * - Other addresses try to call adapter.skim()
 * - Call skimManager.skimAdapter() with no rewards present in Adapter
 * - Call skimManager.skimAdapter() with rewards present in Adapter and receive successfully
 * - Call skimManager.skimAdapter() with rewards present in Adapter and receive successfully but parent token is the same as reward token
 */
contract SkimManagerUnitTests is Test {
    // -------- State Variables --------
    Vm.Wallet private deployer;
    Vm.Wallet private operator;
    Vm.Wallet private user; // Normal user, no roles

    SkimManager public skimManager;
    IAdapter public adapter;
    IMerklDistributor public merklDistributor;

    function setUp() public {
        forkMainnet(23509633);

        deployer = vm.createWallet("deployer");
        operator = vm.createWallet("operator");
        user = vm.createWallet("user");

        adapter = IAdapter(0x729538D4b1EB4B1fcC2d9366b11c3f84676b867C);
        merklDistributor = IMerklDistributor(0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae);

        DeploySkimManager deploySkimManager = new DeploySkimManager();

        vm.prank(deployer.addr);
        deploySkimManager.setUp_(deployer.privateKey);
        skimManager = SkimManager(deploySkimManager.run());

        // Grant Operator role
        vm.prank(deployer.addr); // Deployer is the admin
        skimManager.grantRole(keccak256("OPERATOR_ROLE"), operator.addr);

        // The Adapter needs to set the SkimManager as the skimRecipient
        // NOTE: In order to change the skimRecipient, we need to act as the parent vault owner
        // which is the following address: 0x0000aeB716a0DF7A9A1AAd119b772644Bc089dA8 
        vm.prank(0x0000aeB716a0DF7A9A1AAd119b772644Bc089dA8);
        adapter.setSkimRecipient(address(skimManager));

        // The Adapter needs to whitelist the SkimManager to claim rewards from the Merkl URD
        vm.prank(address(adapter));
        merklDistributor.toggleOperator(address(adapter), address(skimManager));
    }

    // -------- Tests --------

    function test_OtherAddressesTryToCallAdapterSkim() public {
        vm.prank(user.addr);
        vm.expectRevert();
        adapter.skim(address(0));
    }

    // -------- Utility Functions --------

    function forkMainnet(uint256 blockNumber) public returns (uint256 forkId) {
        // Default, use with Mainnet. Mainnet rpc key is defined in .env
        forkId = vm.createFork(vm.envString("MAINNET_RPC_URL"), blockNumber);
        vm.selectFork(forkId);
    }

    function forkMainnet(uint256 blockNumber, string memory rpcKey) public returns (uint256 forkId) {
        // Can be used with other networks. Define rpcKey in .env
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
