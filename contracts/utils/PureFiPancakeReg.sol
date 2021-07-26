// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../../openzeppelin-contracts-master/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IBotProtectorMaster.sol";
import "../pancake/interfaces/IPancakeRouter01.sol";

contract PureFiPancakeReg {

   event LiquidityAdded(uint amountToken, uint amountETH, uint liquidity);
   
   function routerAddress() public pure returns(address) {
      return 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F;
   }

   function registerPair(address pureFiToken, address botProtection, uint256 amountUFI, uint256 firewallBlockLength, uint256 firewallTimeLength) external payable {
      // 1) Create pair
      IPancakeRouter01 router = IPancakeRouter01(routerAddress());
      // 3) Enable protection
      IBotProtectorMaster(botProtection).prepareBotProtection(firewallBlockLength,firewallTimeLength);
      // add liquidity
      IERC20(pureFiToken).approve(address(router), amountUFI);
      (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value:msg.value}(
        pureFiToken,
        amountUFI,
        amountUFI,
        msg.value,
        msg.sender,
        block.timestamp + 30 seconds
      );

      emit LiquidityAdded(amountToken, amountETH , liquidity);     
   } 

   function getPairAddress(address pureFiToken) public pure returns (address){
      IPancakeRouter01 router = IPancakeRouter01(routerAddress());
      address wethAddress = router.WETH();
      return pairFor(router.factory(), pureFiToken, wethAddress);
   }

   // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'PancakeLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PancakeLibrary: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66' // init code hash
            )))));
    }
}

