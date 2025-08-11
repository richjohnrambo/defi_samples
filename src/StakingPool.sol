// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title KK Token 接口
 * @dev 用于铸造奖励的代币
 */
interface IToken {
    function mint(address to, uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
}

/**
 * @title Staking 接口
 * @dev 用户可以质押 ETH 来赚取 KK Token 奖励
 */

/**
 * @title Staking Interface
 */
interface IStaking {
    /**
     * @dev 质押 ETH 到合约
     */
    function stake()  payable external;

    /**
     * @dev 赎回质押的 ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external; 

    /**
     * @dev 领取 KK Token 收益
     */
    function claim() external;

    /**
     * @dev 获取质押的 ETH 数量
     * @param account 质押账户
     * @return 质押的 ETH 数量
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev 获取待领取的 KK Token 收益
     * @param account 质押账户
     * @return 待领取的 KK Token 收益
     */
    function earned(address account) external view returns (uint256);
}


/**
 * @title 借贷市场接口（示例）
 * @dev 假设借贷市场接受 ETH 存款，并产生利息
 */
interface ILendingMarket {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract StakingPool is IStaking {
    IToken public kkToken;              // 奖励代币合约
    ILendingMarket public lending;      // 借贷市场合约
    uint256 public rewardPerBlock = 10 * 1e18; // 每个区块奖励 10 KK（假设18位精度）
    
    uint256 public totalStaked;         // 总质押 ETH 数量
    uint256 public lastRewardBlock;     // 上一次更新奖励的区块
    uint256 public accRewardPerShare;   // 累积奖励（每单位ETH对应多少奖励，扩大1e18倍计算）

    struct UserInfo {
        uint256 amount;      // 用户质押的ETH数量
        uint256 rewardDebt;  // 用户已领取过的奖励部分（用于计算应得奖励）
    }

    mapping(address => UserInfo) public userInfo;

    constructor(address _kkToken, address _lending) {
        kkToken = IToken(_kkToken);
        lending = ILendingMarket(_lending);
        lastRewardBlock = block.number;
    }

    /**
     * @dev 更新池子的奖励状态
     */
    function updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 blocks = block.number - lastRewardBlock;
        uint256 reward = blocks * rewardPerBlock;

        // 累积奖励/每份ETH
        accRewardPerShare += reward * 1e18 / totalStaked;
        lastRewardBlock = block.number;
    }

    /**
     * @dev 质押 ETH
     */
    function stake() external payable override {
        require(msg.value > 0, "Must stake > 0");
        updatePool();
        UserInfo storage user = userInfo[msg.sender];

        // 如果用户之前有质押，先结算奖励
        if (user.amount > 0) {
            uint256 pending = user.amount * accRewardPerShare / 1e18 - user.rewardDebt;
            if (pending > 0) {
                kkToken.mint(msg.sender, pending);
            }
        }

        // 更新质押数据
        user.amount += msg.value;
        totalStaked += msg.value;
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;

        // 把质押的 ETH 存入借贷市场赚利息
        lending.deposit{value: msg.value}();
    }

    /**
     * @dev 赎回 ETH
     */
    function unstake(uint256 amount) external override {
        require(amount > 0, "amount=0");
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "Not enough staked");

        updatePool();

        // 结算奖励
        uint256 pending = user.amount * accRewardPerShare / 1e18 - user.rewardDebt;
        if (pending > 0) {
            kkToken.mint(msg.sender, pending);
        }

        // 更新质押数据
        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;

        // 从借贷市场取回 ETH
        lending.withdraw(amount);

        // 转给用户
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev 领取 KK Token 收益
     */
    function claim() external override {
        updatePool();
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = user.amount * accRewardPerShare / 1e18 - user.rewardDebt;
        require(pending > 0, "No rewards");
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;
        kkToken.mint(msg.sender, pending);
    }

    /**
     * @dev 获取用户质押 ETH 数量
     */
    function balanceOf(address account) public view override returns (uint256) {
        return userInfo[account].amount;
    }

    /**
     * @dev 获取用户待领取的 KK Token 收益
     */
    function earned(address account) public view override returns (uint256) {
        UserInfo storage user = userInfo[account];
        uint256 _accRewardPerShare = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked != 0) {
            uint256 blocks = block.number - lastRewardBlock;
            uint256 reward = blocks * rewardPerBlock;
            _accRewardPerShare += reward * 1e18 / totalStaked;
        }
        return user.amount * _accRewardPerShare / 1e18 - user.rewardDebt;
    }

    // 允许接收ETH
    receive() external payable {}
}
