// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../../openzeppelin-contracts-master/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IBotProtectorMaster.sol";
import "../uniswap/RouterInterface.sol";
import "../uniswap/FactoryInterface.sol";

contract PureFiUniswapReg {

   event LiquidityAdded(uint amountToken, uint amountETH, uint liquidity);
   
   function routerAddress() public pure returns(address) {
      return 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
   }

   function registerPair(address pureFiToken, address botProtection, uint256 amountUFI, uint256 firewallBlockLength, uint256 firewallTimeLength) public payable {
      // 1) Create pair
      IUniswapV2Router01 router = IUniswapV2Router01(routerAddress());
      // 3) Enable protection
      IBotProtectorMaster(botProtection).prepareBotProtection(firewallBlockLength,firewallTimeLength);
      // add liquidity
      IERC20(pureFiToken).approve(address(router), amountUFI);
      (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value:msg.value}(
        pureFiToken,
        amountUFI,
        0,
        0,
        msg.sender,
        block.timestamp
      );

      emit LiquidityAdded(amountToken, amountETH , liquidity);     
   } 

   function getPairAddress(address pureFiToken) public pure returns (address){
      IUniswapV2Router01 router = IUniswapV2Router01(routerAddress());
      return pairFor(router.factory(),pureFiToken, router.WETH());
   }

   // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            )))));
    }

     // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }
}

