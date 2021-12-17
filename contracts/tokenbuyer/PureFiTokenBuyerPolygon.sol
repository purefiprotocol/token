pragma solidity ^0.8.0;


import "../uniswap/RouterInterface.sol";
import "../uniswap/interfaces/IUniswapV2Pair.sol";
import "../../openzeppelin-contracts-master/contracts/access/Ownable.sol";
import "./ITokenBuyer.sol";

contract PureFiTokenBuyerPolygon is Ownable , ITokenBuyer{

    uint16 public constant PERCENT_DENOM = 10000;
    uint16 public slippage;// 

    event TokenPurchase(address indexed who, uint256 bnbIn, uint256 ufiOut);

    constructor(){
        slippage = 100;
    }


    function changeSlippage(uint16 _slippage) public onlyOwner{
        require(_slippage <= PERCENT_DENOM, "Slippage too high");
        slippage = _slippage;
    }

    function routerAddress() public pure returns(address) {
      return 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    }

    function getPathUFI() internal view returns(address[] memory){
        address[] memory path = new address[](2);
        address wethAddress = IUniswapV2Router01(routerAddress()).WETH();
        path[0] = wethAddress;
        path[1] = 0x3c205C8B3e02421Da82064646788c82f7bd753B9; //ufi
        return path;
    }

    function getPathSafle() internal view returns(address[] memory){
        address[] memory path = new address[](3);
        address wethAddress = IUniswapV2Router01(routerAddress()).WETH();
        path[0] = wethAddress;
        path[1] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;//usdt
        path[2] = 0x04b33078Ea1aEf29bf3fB29c6aB7B200C58ea126;//safle
        return path;
    }

    function buyToken(address _token, address _to) external override payable returns (uint256){
        if(_token == 0x04b33078Ea1aEf29bf3fB29c6aB7B200C58ea126){
            return _buyTokens(_to, getPathSafle());
        }
        else if(_token == 0x3c205C8B3e02421Da82064646788c82f7bd753B9){
            return _buyTokens(_to, getPathUFI());
        }
        else {
            revert("unknown token");
        }
    }  


    function _buyTokens(address _to, address[] memory path) internal returns (uint256){

        IUniswapV2Router01 router = IUniswapV2Router01(routerAddress());

        uint[] memory amounts = router.getAmountsOut(msg.value, path);

        uint256 targetTokensExpected = amounts[amounts.length-1];
        
        uint256 minTargetTokensExpected = targetTokensExpected * (PERCENT_DENOM - slippage) / PERCENT_DENOM;

        uint[] memory out = router.swapExactETHForTokens{value: msg.value}(minTargetTokensExpected, path, _to, block.timestamp);
        emit TokenPurchase(_to, out[0], out[out.length-1]);
        
        return out[out.length-1];
    }

}