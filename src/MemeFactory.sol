// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MemeToken} from "./MemeToken.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {console} from "forge-std/console.sol";

contract MemeFactory {
    address public owner;
    address public uniswapRouter;

    mapping(address => address) public memeTokens;

    constructor(address _uniswapRouter) {
        owner = msg.sender;
        uniswapRouter = _uniswapRouter;
    }

    function deployMeme(
        string memory symbol,
        uint totalSupply,
        uint perMint,
        uint price,
        address _tokenIssuer,
        address _tokenPlatformOwner
    ) public returns (address) {
        MemeToken newMemeToken = new MemeToken(
            symbol,
            totalSupply,
            perMint,
            price,
            _tokenIssuer,
            _tokenPlatformOwner,
            uniswapRouter
        );
        newMemeToken.transferOwnership(address(this));
        memeTokens[_tokenIssuer] = address(newMemeToken);
        return address(newMemeToken);
    }

    function mintMeme(address tokenAddr) public payable {
        MemeToken memeToken = MemeToken(tokenAddr);
        uint perMint = memeToken.perMint();
        uint requiredFee = memeToken.price() * perMint;
        require(msg.value == requiredFee, "Incorrect fee");
        
        memeToken.mint{value: msg.value}(msg.sender, perMint);
    }
    
    function buyMeme(address tokenAddr) public payable {
        require(msg.value > 0, "ETH amount must be greater than zero");

        MemeToken memeToken = MemeToken(tokenAddr);
        IUniswapV2Router02 router = IUniswapV2Router02(uniswapRouter);

        address[] memory path = new address[](2);
        path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on Mainnet
        path[1] = tokenAddr;
        
        uint[] memory amounts = router.getAmountsOut(msg.value, path);
        uint amountOut = amounts[1];
        
        uint mintPricePerToken = memeToken.price();
        
        uint uniswapPricePerToken = (msg.value * 1e18) / amountOut;
        console.log("Uniswap price per token:", uniswapPricePerToken);
        console.log("Mint price per token:", mintPricePerToken);
        console.log("msg value:", msg.value);
        if (uniswapPricePerToken <= mintPricePerToken) {
            router.swapExactETHForTokens{value: msg.value}(
                0,
                path,
                msg.sender,
                block.timestamp
            );
        } else {
            revert("Uniswap price is not better than mint price");
        }
    }

    function getMemeToken(address user) public view returns (address) {
        return memeTokens[user];
    }
}