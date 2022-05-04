// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IUniswapV2Router02} from "./interfaces/uniswap.sol";
import "./StrategyCurveBase.sol";

contract StrategyCurveAave is StrategyCurveBase {
    /* ========== STATE VARIABLES ========== */
    // these will likely change across different wants.

    // Curve stuff
    ICurveFi public constant curve = ICurveFi(0x7f90122BF0700F9E7e1F688fe926940E8839F353); // This is our pool specific to this vault. In this case, it is a zap.

    // we use these to deposit to our curve pool
    address public targetToken; // this is the token we sell into, 0 DAI, 1 USDC, 2 USDT, 3 WBTC, 4 WETH
    uint256 public optimal = 1; // this is the token we sell into, 0 DAI, 1 USDC, 2 USDT, 3 WBTC, 4 WETH

    IERC20 internal constant dai = IERC20(0xd586E7F844cEa2F87f50152665BCbc2C279D8d70);
    IERC20 internal constant usdc = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    IERC20 internal constant usdt = IERC20(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);

    IUniswapV2Router02 internal mainRouter = IUniswapV2Router02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4); // this is the router we swap with except for CRV
    IUniswapV2Router02 internal crvRouter = IUniswapV2Router02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4); // this is the router we swap CRV with, Sushi

    /* ========== CONSTRUCTOR ========== */

    constructor(address _vault, address _gauge, string memory _name) public StrategyCurveBase(_vault, _gauge) {
        // You can set these parameters on deployment to whatever you want
        maxReportDelay = 1 days; // 1 day in seconds
        healthCheck = 0x6fD0f710f30d4dC72840aE4e263c22d3a9885D3B;

        // these are our standard approvals. want = Curve LP token
        want.approve(address(_gauge), type(uint256).max);
        crv.approve(address(crvRouter), type(uint256).max);
        wavax.approve(address(mainRouter), type(uint256).max);

        // set our strategy's name
        stratName = _name;

        // these are our approvals and path specific to this contract
        dai.approve(address(curve), type(uint256).max);
        usdc.approve(address(curve), type(uint256).max);
        usdt.safeApprove(address(curve), type(uint256).max);

        // start off with usdc
        targetToken = address(usdc);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    // these will likely change across different wants.

    function prepareReturn(uint256 _debtOutstanding)
    internal
    override
    returns (
        uint256 _profit,
        uint256 _loss,
        uint256 _debtPayment
    )
    {
        // harvest our rewards from the gauge
        gauge.claim_rewards();
        uint256 crvBalance = crv.balanceOf(address(this));
        uint256 wavaxBalance = wavax.balanceOf(address(this));

        // if we claimed any CRV, then sell it
        if (crvBalance > 0 && voter != address(0)) {
            // keep some of our CRV to increase our boost
            uint256 sendToVoter = crvBalance.mul(keepCRV).div(FEE_DENOMINATOR);
            if (keepCRV > 0) {
                crv.safeTransfer(voter, sendToVoter);
            }

            // check our balance again after transferring some crv to our voter
            crvBalance = crv.balanceOf(address(this));
        }

        // sell our WAVAX and CRV if we have any
        if (wavaxBalance > 0 || crvBalance > 0) {
            _sell(wavaxBalance, crvBalance);
        }

        // deposit our balance to Curve if we have any
        if (optimal == 0) {
            uint256 daiBalance = dai.balanceOf(address(this));
            if (daiBalance > 0) {
                curve.add_liquidity([daiBalance, 0, 0], 0, true);
            }
        } else if (optimal == 1) {
            uint256 usdcBalance = usdc.balanceOf(address(this));
            if (usdcBalance > 0) {
                curve.add_liquidity([0, usdcBalance, 0], 0, true);
            }
        } else if (optimal == 2) {
            uint256 usdtBalance = usdt.balanceOf(address(this));
            if (usdtBalance > 0) {
                curve.add_liquidity([0, 0, usdtBalance], 0, true);
            }
        }

        // debtOustanding will only be > 0 in the event of revoking or if we need to rebalance from a withdrawal or lowering the debtRatio
        uint256 stakedBal = stakedBalance();
        if (_debtOutstanding > 0) {
            if (stakedBal > 0) {
                // don't bother withdrawing if we don't have staked funds
                gauge.withdraw(Math.min(stakedBal, _debtOutstanding));
            }
            uint256 _withdrawnBal = balanceOfWant();
            _debtPayment = Math.min(_debtOutstanding, _withdrawnBal);
        }

        // serious loss should never happen, but if it does (for instance, if Curve is hacked), let's record it accurately
        uint256 assets = estimatedTotalAssets();
        uint256 debt = vault.strategies(address(this)).totalDebt;

        // if assets are greater than debt, things are working great!
        if (assets > debt) {
            _profit = assets.sub(debt);
            uint256 _wantBal = balanceOfWant();
            if (_profit.add(_debtPayment) > _wantBal) {
                // this should only be hit following donations to strategy
                liquidateAllPositions();
            }
        }
        // if assets are less than debt, we are in trouble
        else {
            _loss = debt.sub(assets);
        }

        // we're done harvesting, so reset our trigger if we used it
        forceHarvestTriggerOnce = false;
    }

    // Sells our CRV and/or WAVAX for our target token
    function _sell(uint256 _wavaxBalance, uint256 _crvBalance) internal {
        // sell our WAVAX
        if (_wavaxBalance > 0) {
            address[] memory tokenPath = new address[](2);
            tokenPath[0] = address(wavax);
            tokenPath[1] = address(targetToken);
            IUniswapV2Router02(mainRouter).swapExactTokensForTokens(_wavaxBalance, uint256(0), tokenPath, address(this), block.timestamp);
        }

        // check for CRV balance and sell it if we have any
        if (_crvBalance > 0) {
            address[] memory tokenPath = new address[](3);
            tokenPath[0] = address(crv);
            tokenPath[1] = address(wavax);
            tokenPath[2] = address(targetToken);
            IUniswapV2Router02(crvRouter).swapExactTokensForTokens(_crvBalance, uint256(0), tokenPath, address(this), block.timestamp);
        }
    }

    /* ========== KEEP3RS ========== */

    function harvestTrigger(uint256 callCostinEth) public view override returns (bool) {
        StrategyParams memory params = vault.strategies(address(this));

        // harvest no matter what once we reach our maxDelay
        if (block.timestamp.sub(params.lastReport) > maxReportDelay) {
            return true;
        }

        // trigger if we want to manually harvest
        if (forceHarvestTriggerOnce) {
            return true;
        }

        // otherwise, we don't harvest
        return false;
    }

    // convert our keeper's eth cost into want, we don't need this anymore since we don't use baseStrategy harvestTrigger
    function nativeToWant(uint256 _ethAmount) public view override returns (uint256) {
        return _ethAmount;
    }

    /* ========== SETTERS ========== */

    // These functions are useful for setting parameters of the strategy that may need to be adjusted.
    // Set optimal token to sell harvested funds for depositing to Curve.
    // Default is DAI, but can be set to USDC or USDT as needed by strategist or governance.
    function setOptimal(uint256 _optimal) external onlyAuthorized {
        if (_optimal == 0) {
            targetToken = address(dai);
            optimal = 0;
        } else if (_optimal == 1) {
            targetToken = address(usdc);
            optimal = 1;
        } else if (_optimal == 2) {
            targetToken = address(usdt);
            optimal = 2;
        } else {
            revert("incorrect token");
        }
    }
}
