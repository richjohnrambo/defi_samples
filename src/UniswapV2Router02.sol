// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {WETH9} from "./WETH9.sol";

// 这是一个 Uniswap V2 Router 的简化实现，用于测试。
contract UniswapV2Router02 is IUniswapV2Router02 {
    address public immutable factory;
    address public immutable WETH;

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external override returns (uint amountA, uint amountB, uint liquidity) {
        // 在实际测试中，我们只关心这个函数被调用，具体逻辑可以简化
        amountA = amountADesired;
        amountB = amountBDesired;
        liquidity = 1000; // 返回一个模拟的流动性数量
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external override payable returns (uint amountToken, uint amountETH, uint liquidity) {
        // 在实际测试中，我们只关心这个函数被调用，具体逻辑可以简化
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = 1000; // 返回一个模拟的流动性数量
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external override returns (uint amountA, uint amountB) {
        amountA = liquidity;
        amountB = liquidity;
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override payable returns (uint[] memory amounts) {
        // 模拟 ETH 兑换代币
        amounts = new uint[](path.length);
        amounts[0] = msg.value;
        amounts[1] = 10000; // 模拟一个固定的兑换数量
    }

    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) external override view returns (uint[] memory amounts) {
        // 模拟价格查询
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[1] = amountIn * 10; // 模拟一个固定的价格
    }
}