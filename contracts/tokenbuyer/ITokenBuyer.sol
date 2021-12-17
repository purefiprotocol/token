pragma solidity >=0.5.0;

interface ITokenBuyer {
    function buyToken(address _token, address _to) external payable returns (uint256);
}
