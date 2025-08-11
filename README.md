
StakingPool + 借贷市场 + KK Token（每区块 10 个）——ASCII 流程图（含关键公式）
┌────────────────────────────────────────────────────────────────────────────┐
│                                 用户侧                                     │
│                                                                            │
│  User                      StakingPool Contract                     Lending │
│  UI/Wallet                     (this)                                Market │
│                                                                            │
│   (1) stake()  msg.value            ┌──────────────────────────────┐        │
│  ────────────────────────────────▶  │  stake() (payable)           │        │
│                                     │                              │        │
│                                     │  1) updatePool()             │        │
│                                     │     - calc blocks = now - lastRewardBlock
│                                     │     - reward = blocks * REWARD_PER_BLOCK
│                                     │     - accKKPerShare += reward * 1e12 / totalStaked
│                                     │     - lastRewardBlock = now   │
│                                     │                              │
│                                     │  2) pay pending KK to user if any
│                                     │     pending = user.amount * accKKPerShare/1e12 - rewardDebt
│                                     │                              │
│                                     │  3) lendingMarket.depositETH{value=msg.value}()  ───┐
│                                     │                              │          │
│                                     │  4) user.amount += msg.value │          │
│                                     │     totalStaked += msg.value │          │
│                                     │  5) user.rewardDebt = user.amount * accKKPerShare/1e12
│                                     └──────────────────────────────┘          │
│                                                                               │
│                                                                               │
│   (2) 每区块产出 10 KK 全局 (REWARD_PER_BLOCK)                                 │
│  ────────────────────────────────────────────────────────────────────────────▶│
│                                                                               │
│   (3) unstake(amount)               ┌──────────────────────────────┐          │
│  ◀──────────────────────────────────│  unstake(amount)             │◀─────────┘
│                                     │                              │
│                                     │  1) updatePool()             │
│                                     │  2) pay pending KK to user   │
│                                     │  3) lendingMarket.withdrawETH(amount)
│                                     │  4) user.amount -= amount    │
│                                     │     totalStaked -= amount    │
│                                     │  5) user.rewardDebt = user.amount * accKKPerShare/1e12
│                                     │  6) transfer ETH back to user
│                                     └──────────────────────────────┘
│                                                                               │
│   (4) claim()                        ┌──────────────────────────────┐          │
│  ◀──────────────────────────────────│  claim()                     │
│                                     │  1) updatePool()             │
│                                     │  2) pending = user.amount * accKKPerShare/1e12 - rewardDebt
│                                     │  3) kkToken.mint(user, pending)
│                                     │  4) user.rewardDebt = user.amount * accKKPerShare/1e12
│                                     └──────────────────────────────┘
└────────────────────────────────────────────────────────────────────────────┘

关键变量与公式（实现时必看）
全局常量：

REWARD_PER_BLOCK = 10（每区块产出 10 个 KK）

ACC_PRECISION = 1e12（放大因子防止精度丢失）

池子状态：

lastRewardBlock：上一次累计奖励更新的区块号

accKKPerShare：累计每单位质押（per ETH wei）可分配的 KK（放大 1e12）

用户状态（UserInfo）：

amount：用户当前质押的 ETH（以 wei 计）

rewardDebt：用户上一次交互后记录的 user.amount * accKKPerShare / ACC_PRECISION

更新池子（updatePool()）：

nginx
if block.number <= lastRewardBlock: return
if totalStaked == 0: lastRewardBlock = block.number; return

blocks = block.number - lastRewardBlock
reward = blocks * REWARD_PER_BLOCK
accKKPerShare += reward * ACC_PRECISION / totalStaked
lastRewardBlock = block.number
计算用户可领取（pending）：

ini
pending = user.amount * accKKPerShare / ACC_PRECISION - user.rewardDebt
质押（stake()）主要步骤：

updatePool()

结算并 mint pending（若 >0）

把 msg.value 调用 lendingMarket.depositETH{value: msg.value}()

增加 user.amount 与 totalStaked

更新 user.rewardDebt = user.amount * accKKPerShare / ACC_PRECISION

赎回（unstake(amount)）主要步骤：

updatePool()

结算并 mint pending

调用 lendingMarket.withdrawETH(amount)

减少 user.amount 与 totalStaked

更新 user.rewardDebt

payable(user).transfer(amount)

实现/安全提醒（快速清单）
借贷市场接口必须匹配真实合约（deposit/withdraw 是否需要额外参数或有回调）。

lendingMarket.depositETH 可能会改变合约内 ETH 余额（有的市场返回 cToken 或有不同流动性模型），注意同步 totalStaked 与借贷市场中的实际可提现量。

注意 transfer 与 call 的安全用法（避免 reentrancy）；关键函数应加 nonReentrant（OpenZeppelin ReentrancyGuard）。

处理带转账费/代币钩子的特殊 LP（若借贷市场对 ETH 做了包装需适配）。

当 totalStaked == 0 时不应分配奖励（直接 advance lastRewardBlock）。

kkToken.mint 权限：合约需要有 mint 权限或管理员角色；或改为合约持有预铸余额并 transfer。

精度与溢出：Solidity >=0.8 已有溢出检查，但仍需谨慎处理乘法顺序以避免临时超大值。


