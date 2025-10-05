// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {SkimManager} from "../src/SkimManager.sol";

/**
 * @notice script to deploy the SkimManager
 * Sets up the roles and contracts
 */
contract DeploySkimManager is Script {
    // -------- Errors --------
    error InvalidSender();

    // -------- State Variables --------
    Vm.Wallet public deployerWallet;
    address merklDistributor = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address swapper = 0x732ca7E5b02f3E9Fe8D5CA7B17B1D1ea47A57A1B; // Box swapper on Ethereum

    // -------- Modifiers --------
    modifier asDeployer() {
        if (deployerWallet.privateKey != 0) {
            vm.startBroadcast(deployerWallet.privateKey);
        } else {
            vm.startBroadcast();
        }

        _;

        vm.stopBroadcast();
    }

    function setUp() public {
        deployerWallet.addr = msg.sender;

        vm.label(msg.sender, "Deployer EOA");
    }

    /// @notice Sets up the script with a given wallet
    /// @dev This function is meant to be used by unit tests
    function setUp_(uint256 _privateKey) public {
        if (msg.sender != vm.addr(_privateKey)) revert InvalidSender();

        deployerWallet.privateKey = _privateKey;
        deployerWallet.addr = vm.addr(_privateKey);

        vm.label(msg.sender, "Deployer EOA");
    }

    function run() public returns (address) {
        console2.log(string.concat("Deployer EOA: ", vm.toString(deployerWallet.addr)));

        return _run();
    }

    function _run() internal asDeployer returns (address) {
        SkimManager skimManager = new SkimManager(deployerWallet.addr, swapper, merklDistributor);
        console2.log("SkimManager deployed at: ", address(skimManager));

        // Grant Operator role
        skimManager.grantRole(keccak256("OPERATOR_ROLE"), deployerWallet.addr);

        // Sanity
        require(skimManager.hasRole(keccak256("OPERATOR_ROLE"), deployerWallet.addr), "Operator role not granted");

        return address(skimManager);
    }
}
