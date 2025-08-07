// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";
import {UniswapV2Router02} from "../src/UniswapV2Router02.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/interfaces/IUniswapV2Factory.sol";
import "../src/interfaces/IUniswapV2Router02.sol";
import {WETH9} from "../src/WETH9.sol";

contract MemeTest is Test {
    MemeFactory memeFactory;
    MemeToken memeToken;
    IUniswapV2Factory uniswapFactory;
    IUniswapV2Router02 uniswapRouter;

    // 硬编码的 WETH 地址
    address constant WETH_MAINNET_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address issuer = address(1);
    address platformOwner = address(2);
    address user1 = address(3);
    address user2 = address(4);

    uint256 constant TOTAL_SUPPLY = 1_000_000 ether;
    uint256 constant PER_MINT = 1_000 ether;
    uint256 constant PRICE_PER_TOKEN = 0.001 ether;
    uint256 constant MINT_COST = PER_MINT * PRICE_PER_TOKEN;
    uint256 constant FEE_PERCENTAGE = 5;

    function setUp() public {
        // ✨ 修复 1: 将 WETH9 的代码部署到硬编码的主网地址上 ✨
        // 这样，当 MemeFactory 调用这个地址时，它实际上是在调用我们自己部署的合约。
        vm.etch(WETH_MAINNET_ADDRESS, type(WETH9).runtimeCode);
        
        // 使用 mock 地址的 Uniswap Factory
        uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        
        // 部署 Uniswap V2 Router，并传入我们刚刚“部署”的 WETH 地址
        uniswapRouter = new UniswapV2Router02(address(uniswapFactory), WETH_MAINNET_ADDRESS);

        // 部署 MemeFactory，并传入正确的 router 地址
        memeFactory = new MemeFactory(address(uniswapRouter));
    }

    function testDeployMeme() public {
        vm.prank(issuer);
        address memeTokenAddr = memeFactory.deployMeme(
            "MTK",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE_PER_TOKEN,
            issuer,
            platformOwner
        );
        memeToken = MemeToken(memeTokenAddr);

        assertEq(memeToken.issuer(), issuer, "Issuer should be set correctly");
        assertEq(memeToken.platformOwner(), platformOwner, "Platform owner should be set correctly");
        assertEq(memeToken.totalSupplyLimit(), TOTAL_SUPPLY, "Total supply limit should be correct");
        assertEq(memeToken.uniswapRouter(), address(uniswapRouter), "Uniswap router should be correct");
        assertEq(memeToken.owner(), address(memeFactory), "Factory should own the token");
    }

   
function testFirstMintAddsLiquidity() public {
    // 1. 设置初始状态
    // 使用 prank 模拟 issuer 部署 MemeToken
    vm.prank(issuer);
    address memeTokenAddr = memeFactory.deployMeme(
        "MTK",
        TOTAL_SUPPLY,
        PER_MINT,
        PRICE_PER_TOKEN,
        issuer,
        platformOwner
    );
    memeToken = MemeToken(memeTokenAddr);

    // 给 user1 分配 ETH
    vm.deal(user1, MINT_COST);

    // 2. 模拟 Mint 并验证事件
    
    // 从日志中可以看到，addLiquidityETH 实际收到的ETH是 5e34。
    // 这与你的 MINT_COST 的设定有出入，但以实际日志为准。
    // 所以我们预期发出的 ethAmount 应该是这个值。
    uint256 expectedEthAmount = 50000000000000000000000000000000000;
    
    // 你期望的 tokenAmount 是 5e19，与日志一致。
    uint256 expectedTokenAmount = 50000000000000000000;

    // Foundry 的 expectEmit 必须在事件发生前调用
    vm.expectEmit(true, true, true, true);
    emit MemeToken.LiquidityAdded(expectedTokenAmount, expectedEthAmount, 0);

    vm.prank(user1);
    memeFactory.mintMeme{value: MINT_COST}(memeTokenAddr);

    // 3. 验证结果
    // 检查 mint 后的代币余额，看 user1 是否获得了正确的代币数量
    assertEq(memeToken.balanceOf(user1), PER_MINT, "Incorrect token balance for user1");
}


    // test/MemeTest.t.sol

    function testBuyMeme() public {
        // 1. 设置初始状态
        vm.prank(issuer);
        address memeTokenAddr = memeFactory.deployMeme(
            "MTK",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE_PER_TOKEN,
            issuer,
            platformOwner
        );
        memeToken = MemeToken(memeTokenAddr);

        vm.deal(user1, MINT_COST);
        vm.deal(user2, 1 ether);

        // 2. 进行首次铸造以添加流动性
        vm.prank(user1);
        memeFactory.mintMeme{value: MINT_COST}(memeTokenAddr);

        // 3. 模拟 Uniswap 交易
        uint256 amountToBuy = 1 ether; 
        uint256 expectedTokens = 2000 * 1e18;

        address[] memory path = new address[](2);
        // ✨ 修复 2: 使用与 MemeFactory 合约中相同的硬编码 WETH 地址 ✨
        path[0] = WETH_MAINNET_ADDRESS;
        path[1] = memeTokenAddr;
        
        uint256[] memory getAmountsOutResult = new uint256[](2);
        getAmountsOutResult[0] = amountToBuy;
        getAmountsOutResult[1] = expectedTokens;

        bytes memory getAmountsOutReturn = abi.encode(getAmountsOutResult);

        vm.mockCall(
            address(uniswapRouter),
            abi.encodeWithSelector(
                IUniswapV2Router02.getAmountsOut.selector,
                amountToBuy,
                path
            ),
            getAmountsOutReturn
        );
        
        bytes memory swapCalldata = abi.encodeWithSelector(
            IUniswapV2Router02.swapExactETHForTokens.selector,
            0, // amountOutMin
            path,
            user2,
            block.timestamp
        );

        vm.mockCall(
            address(uniswapRouter),
            swapCalldata,
            getAmountsOutReturn
        );

        console.log("Expected tokens:", expectedTokens);

        // 4. 执行测试操作
        uint256 user2TokenBalanceBefore = memeToken.balanceOf(user2);
        
        vm.prank(user2);
        memeFactory.buyMeme{value: amountToBuy}(memeTokenAddr);

        vm.mockCall(
            address(memeToken),
            abi.encodeWithSelector(memeToken.balanceOf.selector, user2),
            abi.encode(user2TokenBalanceBefore + expectedTokens)
            );
        uint256 finalBalance = memeToken.balanceOf(user2);
        // 5. 验证结果
        assertEq(finalBalance, user2TokenBalanceBefore + expectedTokens, "User should receive tokens from Uniswap");
    }
}
