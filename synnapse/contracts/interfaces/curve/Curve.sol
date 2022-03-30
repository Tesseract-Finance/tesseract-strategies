// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ICurveFi {
    function getVirtualPrice() external view returns (uint256);

    // stableswap pools
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external payable returns (uint256);

    function addLiquidity(
        uint256[2] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external payable returns (uint256);

    function getToken(uint8) external view returns (address);

    function pool() external view returns (address);

    function removeLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 minAmount,
        uint256 deadline
    ) external returns (uint256);
}
