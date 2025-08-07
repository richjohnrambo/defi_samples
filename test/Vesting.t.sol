// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Vesting.sol";
import "../src/CloudToken.sol"; // 导入你的 CloudToken 合约

contract VestingTest is Test {
    Vesting public vesting;
    CloudToken public cloudToken; // 使用 CloudToken 类型
    
    address public beneficiary = address(0x1337);
    uint256 public totalVestedAmount = 1_000_000 * 10**18; // 100万 ERC20

    function setUp() public {
        // 部署 CloudToken 代币
        // 假设 CloudToken 的构造函数需要一个初始供应量
        cloudToken = new CloudToken();
        
        // 部署 Vesting 合约
        vesting = new Vesting(
            beneficiary,
            address(cloudToken),
            totalVestedAmount
        );
        
        // 授权 Vesting 合约从测试账户中转移代币
        cloudToken.approve(address(vesting), totalVestedAmount);
        
        // 将所有代币转移到 Vesting 合约
        // 注意：这里需要 Vesting 合约拥有转移权限
        // 所以我们用 CloudToken.transferFrom
        // 或者，如果你在部署 Vesting 合约时已经拥有代币，可以直接 transfer。
        // 为了简化，我们使用 transfer。
        cloudToken.transfer(address(vesting), totalVestedAmount);

        // 验证 Vesting 合约是否收到代币
        assertEq(cloudToken.balanceOf(address(vesting)), totalVestedAmount);
    }

    // ... 以下测试函数保持不变 ...

    // 测试 Cliff 期内无法释放代币
    function testCliffPeriod() public {
        vm.warp(block.timestamp + 11 * 30 days);
        assertEq(vesting.vestedAmount(), 0);
        vm.expectRevert("No tokens to release");
        vesting.release();
    }

    // 测试 Cliff 期结束后，可释放数量从 0 开始
    function testAfterCliff() public {
        vm.warp(block.timestamp + 13 * 30 days); // 1年1天后
        uint256 expectedVested = totalVestedAmount / 24;
        assertEq(vesting.vestedAmount(), expectedVested);
        vesting.release();
        assertEq(cloudToken.balanceOf(beneficiary), expectedVested);
        vm.expectRevert("No tokens to release");
        vesting.release();
    }

    // 测试 Vesting 期结束后，所有代币都可以释放
    function testFullVestingPeriod() public {
        vm.warp(block.timestamp + 37 * 30 days);
        assertEq(vesting.vestedAmount(), totalVestedAmount);
        vesting.release();
        assertEq(cloudToken.balanceOf(beneficiary), totalVestedAmount);
    }
}