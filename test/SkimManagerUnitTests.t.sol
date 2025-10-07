// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, Vm} from "forge-std/Test.sol";
import {SkimManager} from "../src/SkimManager.sol";
import {DeploySkimManager} from "../script/DeploySkimManager.s.sol";
import {IAdapter} from "../src/interfaces/IAdapter.sol";
import {IMerklDistributor} from "../src/interfaces/IMerklDistributor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultV2} from "../src/interfaces/IVaultV2.sol";

contract SkimManagerUnitTests is Test {
    // -------- State Variables --------
    Vm.Wallet private deployer;
    Vm.Wallet private operator;
    Vm.Wallet private user; // Normal user, no roles

    SkimManager public skimManager;
    IAdapter public adapter;
    IMerklDistributor public merklDistributor;
    IERC20 public rewardToken;

    function setUp() public {
        forkMainnet(23509986);

        deployer = vm.createWallet("deployer");
        operator = vm.createWallet("operator");
        user = vm.createWallet("user");

        adapter = IAdapter(0x729538D4b1EB4B1fcC2d9366b11c3f84676b867C);
        merklDistributor = IMerklDistributor(0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae);
        rewardToken = IERC20(0x58D97B57BB95320F9a05dC918Aef65434969c2B2); // MORPHO Token

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

    function test_otherAddressesTryToCallAdapterSkim() public {
        vm.prank(user.addr);
        vm.expectRevert();
        adapter.skim(address(0));
    }

    function test_skimManagerCanCallAdapterSkim() public {
        vm.prank(operator.addr);
        vm.expectRevert(SkimManager.NothingToSkim.selector); // Won't skim anything just yet until rewards are claimed
        skimManager.skimAdapter(address(adapter), address(rewardToken), "", 0);
    }

    function test_skimAndReinvest() public {
        // Allot some tokens to the adapter to simulate rewards to skim
        deal(address(rewardToken), address(adapter), 20e18); // 20 MORPHO tokens given to the adapter

        IERC20 parentToken = IERC20(IVaultV2(adapter.parentVault()).asset());
        uint256 parentTokenBalanceBefore = parentToken.balanceOf(address(adapter.parentVault()));

        vm.prank(operator.addr);
        skimManager.skimAdapter(address(adapter), address(rewardToken), "", 0);

        uint256 parentTokenBalanceAfter = parentToken.balanceOf(address(adapter.parentVault()));

        // Since 1 MORPHO token is >1 USDC, the skim should at least be 20 USDC
        assertGt(parentTokenBalanceAfter - parentTokenBalanceBefore, 20e6);
    }

    function test_claimAndSkim() public {
        address[] memory users = new address[](1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);

        assertEq(rewardToken.balanceOf(address(adapter)), 0);

        // The following values from the Merkl API are valid proofs for this particular block we've forked from
        users[0] = address(adapter);
        tokens[0] = address(rewardToken);
        amounts[0] = 142007142514017; // From API
        proofs[0] = new bytes32[](18); // From API
        proofs[0][0] = 0xa72df3aa96a81395b95ab391c27346498b3f87319f9ec2a9859495327730ec64;
        proofs[0][1] = 0x38eb6a02190386151cb199a3a2e327024ccb22099ed1d4e5a98ae333f1c14fc7;
        proofs[0][2] = 0xc49a75f5557b525a7909e6667b108760febcf461c6d3af37008ab60a44d18177;
        proofs[0][3] = 0xfa7949e17eeebb26b8dbf861596c57c05b6dd0779b11f3073ee232e9ae848ee5;
        proofs[0][4] = 0x71537e782bec3b84b8fc544bbb0fe042323a32822d9347a661d0a0a76e28afa0;
        proofs[0][5] = 0x18d371d0561d3a7949160b6dbbbb6da289d5c16b9d9860b74522774cd3bbe4ec;
        proofs[0][6] = 0x43c90baa6ddf64ac1b11240c2ba29a40c87ad28a3600f631dbc00f5e6bc1c7bf;
        proofs[0][7] = 0xbf1e404e19082b82f8b672863899390363c33155458ee60f5e5165833eca84bd;
        proofs[0][8] = 0xca2ead46e7db09548502d75e38ff21205a06aa123952661e434e283fe03d113b;
        proofs[0][9] = 0xefee46958ec337575c2588125d898e0143c05e1fb72961896642fefbb22f8a5d;
        proofs[0][10] = 0x52b3bbca3cdbd38721d054c6f8f268bda1c2b486438ee648c7c738b3c8adbd1c;
        proofs[0][11] = 0xb37c5a74c32f1f0aea3c3b2938c2df4cf6f4f82153634d6988f076eaeffae885;
        proofs[0][12] = 0xc915a2e475369e4cf21c7618219fe8663f118a1485e605ce8f44c87065ecd526;
        proofs[0][13] = 0x604961f8ca32a1eda082cc809a72ca4a19eb782de721d7b2a046137d2a32c7c0;
        proofs[0][14] = 0x0a9ddfce548462fefd9623c2382057f694ac0d9cf3b08266dc82d40f59d277de;
        proofs[0][15] = 0xdadf13382f8d1ab69171804261554795d3d2165aa47e097be6d5ef330241f6a9;
        proofs[0][16] = 0xcbbc9857411ca9b79eb673bddd7ebb54b9f168cb32821f7ad2a033536d8dea78;
        proofs[0][17] = 0xa3e8b266355aa0689e8036e87509b68fc66598f83bdef9ae4de6a4847fc67f32;

        vm.prank(operator.addr);
        skimManager.claimRewards(users, tokens, amounts, proofs);
        assertEq(rewardToken.balanceOf(address(adapter)), amounts[0]);

        // Skim these rewards and reinvest into the parent vault
        vm.prank(operator.addr);
        skimManager.skimAdapter(address(adapter), address(rewardToken), "", 0);

        assertEq(rewardToken.balanceOf(address(adapter)), 0); // Now transferred to the parent vault
    }

    function test_othersCantClaimRewards() public {
        address[] memory users = new address[](1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);

        assertEq(rewardToken.balanceOf(address(adapter)), 0);

        // The following values from the Merkl API are valid proofs for this particular block we've forked from
        users[0] = address(adapter);
        tokens[0] = address(rewardToken);
        amounts[0] = 142007142514017; // From API
        proofs[0] = new bytes32[](18); // From API
        proofs[0][0] = 0xa72df3aa96a81395b95ab391c27346498b3f87319f9ec2a9859495327730ec64;
        proofs[0][1] = 0x38eb6a02190386151cb199a3a2e327024ccb22099ed1d4e5a98ae333f1c14fc7;
        proofs[0][2] = 0xc49a75f5557b525a7909e6667b108760febcf461c6d3af37008ab60a44d18177;
        proofs[0][3] = 0xfa7949e17eeebb26b8dbf861596c57c05b6dd0779b11f3073ee232e9ae848ee5;
        proofs[0][4] = 0x71537e782bec3b84b8fc544bbb0fe042323a32822d9347a661d0a0a76e28afa0;
        proofs[0][5] = 0x18d371d0561d3a7949160b6dbbbb6da289d5c16b9d9860b74522774cd3bbe4ec;
        proofs[0][6] = 0x43c90baa6ddf64ac1b11240c2ba29a40c87ad28a3600f631dbc00f5e6bc1c7bf;
        proofs[0][7] = 0xbf1e404e19082b82f8b672863899390363c33155458ee60f5e5165833eca84bd;
        proofs[0][8] = 0xca2ead46e7db09548502d75e38ff21205a06aa123952661e434e283fe03d113b;
        proofs[0][9] = 0xefee46958ec337575c2588125d898e0143c05e1fb72961896642fefbb22f8a5d;
        proofs[0][10] = 0x52b3bbca3cdbd38721d054c6f8f268bda1c2b486438ee648c7c738b3c8adbd1c;
        proofs[0][11] = 0xb37c5a74c32f1f0aea3c3b2938c2df4cf6f4f82153634d6988f076eaeffae885;
        proofs[0][12] = 0xc915a2e475369e4cf21c7618219fe8663f118a1485e605ce8f44c87065ecd526;
        proofs[0][13] = 0x604961f8ca32a1eda082cc809a72ca4a19eb782de721d7b2a046137d2a32c7c0;
        proofs[0][14] = 0x0a9ddfce548462fefd9623c2382057f694ac0d9cf3b08266dc82d40f59d277de;
        proofs[0][15] = 0xdadf13382f8d1ab69171804261554795d3d2165aa47e097be6d5ef330241f6a9;
        proofs[0][16] = 0xcbbc9857411ca9b79eb673bddd7ebb54b9f168cb32821f7ad2a033536d8dea78;
        proofs[0][17] = 0xa3e8b266355aa0689e8036e87509b68fc66598f83bdef9ae4de6a4847fc67f32;

        vm.prank(user.addr);
        vm.expectRevert();
        merklDistributor.claim(users, tokens, amounts, proofs);
    }

    function test_rewardSameAsParentToken() public {
        // Simulate the adapter earning rewards in the same token as the parent token
        // The SkimManager should skip the swap and send the rewards directly to the parent vault

        IERC20 parentToken = IERC20(IVaultV2(adapter.parentVault()).asset());
        assertEq(parentToken.balanceOf(address(adapter.parentVault())), 0);

        deal(address(parentToken), address(adapter), 1000e6); // The adapter has earned 1000 USDC in rewards

        vm.prank(operator.addr);
        skimManager.skimAdapter(address(adapter), address(parentToken), "", 0);

        assertEq(parentToken.balanceOf(address(adapter.parentVault())), 1000e6);
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
