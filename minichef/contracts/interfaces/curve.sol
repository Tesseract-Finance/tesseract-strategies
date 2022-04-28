// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ICurveFi {

    // stableswap pools
    function addLiquidity(
        uint256[] memory amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256);
}