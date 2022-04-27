// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/curve.sol";

import "@tesrvaults/contracts/BaseStrategy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";


contract Strategy is BaseStrategy{
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    VaultAPI public yvToken;
    uint256 public lastInvest; // default is 0
    uint256 public minTimePerInvest;// = 3600;
    uint256 public maxSingleInvest;// // 2 hbtc per hour default
    uint256 public slippageProtectionIn;// = 50; //out of 10000. 50 = 0.5%
    uint256 public slippageProtectionOut;// = 50; //out of 10000. 50 = 0.5%
    uint256 public constant DENOMINATOR = 10_000;
    string internal strategyName;


    uint8 private want_decimals;
    uint8 private middle_decimals;

    int128 public curveId;
    uint256 public poolSize;
    bool public hasUnderlying;
    address public metaToken;
    bool public withdrawProtection;


    constructor(
        address _vault
    ) public BaseStrategy(_vault) {}


    function name() external override view returns (string memory) {
        return strategyName;
    }


    function nativeToWant(uint256 _amtInWei) public view override virtual returns (uint256) {}

    function estimatedTotalAssets() public view override returns (uint256) {

    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {

    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {

    }

    function liquidateAllPositions() internal override returns (uint256 _amountFreed) {

    }

    function adjustPosition(uint256 _debtOutstanding) internal override {

    }

    function prepareMigration(address _strategy) internal override {

    }

    function protectedTokens() internal override view returns (address[] memory) {}
}