// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract Vesting {
    // 储存合约创建者，用于管理
    address public immutable owner;

    // 受益人地址
    address public beneficiary;

    // ERC20 代币地址
    IERC20 public token;

    // Vesting 开始时间
    uint256 public immutable start;

    // Cliff 结束时间
    uint256 public immutable cliff;

    // Vesting 结束时间
    uint256 public immutable duration;

    // 已释放的代币数量
    uint256 public released;

    // 锁定的代币总数量
    uint256 public totalAmount;

    // 构造函数，在部署时初始化所有参数
    constructor(
        address _beneficiary,
        address _token,
        uint256 _totalAmount
    ) {
        owner = msg.sender;
        beneficiary = _beneficiary;
        token = IERC20(_token);

        // Vesting 开始时间为合约部署时间
        start = block.timestamp;
        
        // Cliff 12 个月（365天 * 12）
        cliff = start + 365 days;

        // 总释放期为 36 个月 (12个月 Cliff + 24个月线性释放)
        duration = start + 3 * 365 days;
        
        totalAmount = _totalAmount;
    }

    /// @dev 计算当前可释放的代币数量
    function vestedAmount() public view returns (uint256) {
        // 如果当前时间在 Cliff 期之前，则无可释放数量
        if (block.timestamp < cliff) {
            return 0;
        }
        
        // 如果当前时间超过了总释放期，则所有代币都可释放
        if (block.timestamp >= duration) {
            return totalAmount;
        }

        // 计算线性释放的代币数量
        // 释放比例 = (当前时间 - Cliff 结束时间) / (总释放期 - Cliff 结束时间)
        uint256 period = (block.timestamp - cliff)/(30 * 24 * 3600) + 1;
        
        // uint256 timeElapsed = block.timestamp - cliff;
        // uint256 vestingDuration = duration - cliff;
        // console.log("Time Elapsed:", timeElapsed);
        console.log("period", period);

        
        uint256 vested = (totalAmount * period) / 24;
        return vested;
    }

    /// @notice 释放当前可解锁的代币给受益人
    function release() external {
        require(msg.sender == beneficiary || msg.sender == owner, "Only beneficiary or owner can release");
        
        // 计算当前可释放的总量
        uint256 currentVested = vestedAmount();
        
        // 减去已经释放的数量，得到实际可本次释放的数量
        uint256 releasable = currentVested - released;

        // 如果没有可释放的代币，则回退
        require(releasable > 0, "No tokens to release");

        // 更新已释放的数量
        released += releasable;

        // 将代币转给受益人
        token.transfer(beneficiary, releasable);
    }
}