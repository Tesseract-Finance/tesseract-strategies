// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IUniswapV1Factory {
    function getExchange(address) external view returns (address);
}
