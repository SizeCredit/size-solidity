pragma solidity 0.8.23;

interface I1InchAggregator {
    function swap(address fromToken, address toToken, uint256 amount, uint256 minReturn, bytes calldata data)
        external
        payable
        returns (uint256 returnAmount);
}
