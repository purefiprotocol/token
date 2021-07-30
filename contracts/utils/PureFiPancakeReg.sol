// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../../openzeppelin-contracts-master/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IBotProtectorMaster.sol";
import "../pancake/interfaces/IPancakeRouter01.sol";
import "../pancake/interfaces/IPancakeFactory.sol";

contract PureFiPancakeReg {

    address public pancakeRouter;

    constructor(address _router) {
        require(address(0)!= _router, "invalid router");
        pancakeRouter = _router;
    }

   event LiquidityAdded(uint amountToken, uint amountETH, uint liquidity);
   event Balance(uint256 amt);
   
   function routerAddress() public view returns(address) {
      return pancakeRouter;
   }

   function someCoins() public payable{
       emit Balance(msg.value);
   }

   function registerPair(address pureFiToken, address botProtection, uint256 amountUFI, uint256 amountBNBliq, uint256 firewallBlockLength, uint256 firewallTimeLength) external payable {
      // 1) Create pair
      IPancakeRouter01 router = IPancakeRouter01(routerAddress());
      // 3) Enable protection
      IBotProtectorMaster(botProtection).prepareBotProtection(firewallBlockLength, firewallTimeLength);
      // add liquidity
      IERC20(pureFiToken).approve(address(router), amountUFI);
      (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value:amountBNBliq}(
        pureFiToken,
        amountUFI,
        0,
        0,
        msg.sender,
        block.timestamp
      );

      emit LiquidityAdded(amountToken, amountETH , liquidity);     
   } 

//    function getPairAddress2(address pureFiToken) public view returns (address){
//       IPancakeRouter01 router = IPancakeRouter01(routerAddress());
//       return IPancakeFactory(router.factory()).getPair(pureFiToken, router.WETH());
//    }

   function getPairAddress(address pureFiToken) public view returns (address){
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
                hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5' // init code hash
            )))));
    }
}

