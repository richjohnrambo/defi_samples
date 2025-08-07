// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {console} from "forge-std/console.sol";

contract MemeToken is ERC20, Ownable {
    address public issuer; // Meme 发行者
    uint public totalSupplyLimit; // 总供应量限制
    uint public perMint; // 每次铸造数量
    uint public price; // 每个 Meme 铸造的费用（以 wei 为单位）
    uint public currentSupply; // 当前已铸造的 Meme 数量
    address public platformOwner; // 项目方（平台）地址
    address public uniswapRouter; // Uniswap V2 Router 地址

    bool public hasInitialLiquidity; 

    event LiquidityAdded(uint tokenAmount, uint ethAmount, uint liquidity);

    constructor (
        string memory symbol,
        uint _totalSupply,
        uint _perMint,
        uint _price,
        address _issuer,
        address _platformOwner,
        address _uniswapRouter
    ) ERC20("Meme Token", symbol) Ownable(msg.sender) {
        issuer = _issuer;
        platformOwner = _platformOwner;
        totalSupplyLimit = _totalSupply;
        perMint = _perMint;
        price = _price;
        uniswapRouter = _uniswapRouter;
        hasInitialLiquidity = false;
        
        _mint(_issuer, _totalSupply);
        
        // _transferOwnership(_issuer);
    }
    
    function mint(address to, uint amount) external payable onlyOwner {
        require(amount == perMint, "Can only mint perMint amount");

        require(currentSupply + amount <= totalSupplyLimit, "Exceeds total supply");
        
        uint requiredFee = price * amount;
        require(msg.value == requiredFee, "Incorrect fee");

        uint fee = (msg.value * 5) / 100;
        uint ethForIssuer = msg.value - fee;
        
        if (!hasInitialLiquidity) {
            uint tokenForLiquidity = (amount * 5) / 100;
            uint ethForLiquidity = fee;

            require(balanceOf(issuer) >= tokenForLiquidity, "Insufficient issuer token balance for liquidity");

            // 授权 Uniswap Router 转移代币
            ERC20(address(this)).approve(uniswapRouter, tokenForLiquidity);

            // 修复后的函数调用，使用 addLiquidityETH
            IUniswapV2Router02(uniswapRouter).addLiquidityETH{value: ethForLiquidity}(
                address(this),        // MemeToken 的地址
                tokenForLiquidity,    // 期望的代币数量
                0,                    // 最小代币数量（为简化设置）
                0,                    // 最小 ETH 数量（为简化设置）
                issuer,               // 接收 LP 代币的地址
                block.timestamp       // 交易截止时间
            );
            
            hasInitialLiquidity = true;
            emit LiquidityAdded(tokenForLiquidity, ethForLiquidity, 0);

            _transfer(issuer, address(this), tokenForLiquidity);

            (bool sentToPlatform, ) = payable(platformOwner).call{value: fee - ethForLiquidity}("");
            require(sentToPlatform, "Failed to send fee to platform");
        } else {
            (bool sentToPlatform, ) = payable(platformOwner).call{value: fee}("");
            require(sentToPlatform, "Failed to send fee to platform");
        }
            
        (bool sentToIssuer, ) = payable(issuer).call{value: ethForIssuer}("");
        require(sentToIssuer, "Failed to send payment to issuer");
            
        _mint(to, amount);
        currentSupply += amount;
    }
}