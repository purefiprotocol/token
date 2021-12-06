pragma solidity ^0.8.0;

import "./pancake/interfaces/IPancakeRouter01.sol";
import "./pancake/interfaces/IPancakePair.sol";
import "./pancake/interfaces/IPancakeFactory.sol";
import "../openzeppelin-contracts-master/contracts/access/Ownable.sol";

contract PureFITokenBuyer is Ownable {

    uint16 public constant PERCENT_DENOM = 10000;
    uint16 public slippage;// 
    address public targetTokenAddress;

    event TokenPurchase(address indexed who, uint256 bnbIn, uint256 ufiOut);

    constructor(){
        slippage = 100;
        targetTokenAddress = 0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D;
    }

    function changeToken(address newToken) public onlyOwner{
        require(newToken != address(0),"Incorrect token address");
        targetTokenAddress = newToken;
    }

    function changeSlippage(uint16 _slippage) public onlyOwner{
        require(_slippage <= PERCENT_DENOM, "Slippage too high");
        slippage = _slippage;
    }

    receive () external payable {
        _buy(msg.sender);
    }

    function buyFor(address _to) external payable {
        _buy(_to);
    }

    function routerAddress() public pure returns(address) {
      return 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'PancakeLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PancakeLibrary: ZERO_ADDRESS');
    }

    function _buy(address _to) internal {
        IPancakeRouter01 router = IPancakeRouter01(routerAddress());
        address[] memory path = new address[](2);
        address wethAddress = router.WETH();
        path[0] = wethAddress;
        path[1] = targetTokenAddress;

        (address token0, address token1) = sortTokens(wethAddress, targetTokenAddress);
        address pairAddress = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                router.factory(),
                keccak256(abi.encodePacked(token0, token1)),
                hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5' // init code hash
            )))));

        uint256 ufiExpected;
        {
            (uint112 reserve0, uint112 reserve1, ) = IPancakePair(pairAddress).getReserves();
            ufiExpected = token0 == wethAddress ? router.getAmountOut(msg.value, reserve0, reserve1) : router.getAmountOut(msg.value, reserve1, reserve0);
        }
        
        uint256 minUFIExpected = ufiExpected * (PERCENT_DENOM - slippage) / PERCENT_DENOM;

        uint[] memory out = router.swapExactETHForTokens{value: msg.value}(minUFIExpected, path, _to, block.timestamp);
        emit TokenPurchase(_to, out[0], out[1]);
    }

}