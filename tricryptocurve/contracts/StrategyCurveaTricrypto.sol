// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// These are the core Yearn libraries
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "./interfaces/curve.sol";
import "./interfaces/yearn.sol";
import {IUniswapV2Router02} from "./interfaces/uniswap.sol";
import {BaseStrategy, StrategyParams} from "@tesrvaults/contracts/BaseStrategy.sol";

abstract contract StrategyCurveBase is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */
    // these should stay the same across different wants.

    // Curve stuff
    IGauge public constant gauge = IGauge(0x445FE580eF8d70FF569aB36e80c647af338db351); // Curve gauge contract, tokenized, held by strategy

    // keepCRV stuff
    address public voter;
    uint256 public keepCRV; // the percentage of CRV we re-lock for boost (in basis points)
    uint256 internal constant FEE_DENOMINATOR = 10000; // this means all of our fee values are in basis points

    IERC20 internal constant crv = IERC20(0x249848BeCA43aC405b8102Ec90Dd5F22CA513c06);
    IERC20 internal constant wavax = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

    bool internal forceHarvestTriggerOnce; // only set this to true externally when we want to trigger our keepers to harvest for us

    string internal stratName; // set our strategy name here

    /* ========== CONSTRUCTOR ========== */

    constructor(address _vault) public BaseStrategy(_vault) {}

    /* ========== VIEWS ========== */

    function name() external view override returns (string memory) {
        return stratName;
    }

    function stakedBalance() public view returns (uint256) {
        return gauge.balanceOf(address(this));
    }

    function balanceOfWant() public view returns (uint256) {
        return want.balanceOf(address(this));
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return balanceOfWant().add(stakedBalance());
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    // these should stay the same across different wants.

    function adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }
        // Send all of our LP tokens to deposit to the gauge if we have any
        uint256 _toInvest = balanceOfWant();
        if (_toInvest > 0) {
            gauge.deposit(_toInvest);
        }
    }

    function liquidatePosition(uint256 _amountNeeded) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 _wantBal = balanceOfWant();
        if (_amountNeeded > _wantBal) {
            // check if we have enough free funds to cover the withdrawal
            uint256 _stakedBal = stakedBalance();
            if (_stakedBal > 0) {
                gauge.withdraw(Math.min(_stakedBal, _amountNeeded.sub(_wantBal)));
            }
            uint256 _withdrawnBal = balanceOfWant();
            _liquidatedAmount = Math.min(_amountNeeded, _withdrawnBal);
            _loss = _amountNeeded.sub(_liquidatedAmount);
        } else {
            // we have enough balance to cover the liquidation available
            return (_amountNeeded, 0);
        }
    }

    // fire sale, get rid of it all!
    function liquidateAllPositions() internal override returns (uint256) {
        uint256 _stakedBal = stakedBalance();
        if (_stakedBal > 0) {
            // don't bother withdrawing zero
            gauge.withdraw(_stakedBal);
        }
        return balanceOfWant();
    }

    function prepareMigration(address _newStrategy) internal override {
        uint256 _stakedBal = stakedBalance();
        if (_stakedBal > 0) {
            gauge.withdraw(_stakedBal);
        }
    }

    function protectedTokens() internal view override returns (address[] memory) {}

    /* ========== SETTERS ========== */

    // These functions are useful for setting parameters of the strategy that may need to be adjusted.

    // Set the amount of CRV to be locked in veCRV voter from each harvest. Default is 10%.
    function setKeepCRV(uint256 _keepCRV) external onlyAuthorized {
        require(_keepCRV <= 10_000);
        keepCRV = _keepCRV;
    }

    function setVoter(address _voter) external onlyGovernance {
        voter = _voter;
    }

    // This allows us to manually harvest with our keeper as needed
    function setForceHarvestTriggerOnce(bool _forceHarvestTriggerOnce) external onlyAuthorized {
        forceHarvestTriggerOnce = _forceHarvestTriggerOnce;
    }
}

contract StrategyCurveaTricrypto is StrategyCurveBase {
    /* ========== STATE VARIABLES ========== */
    // these will likely change across different wants.

    // Curve stuff
    ICurveFi public constant curve = ICurveFi(0x58e57cA18B7A47112b877E31929798Cd3D703b0f); // This is our pool specific to this vault. In this case, it is a zap.

    // we use these to deposit to our curve pool
    address public targetToken; // this is the token we sell into, 0 DAI, 1 USDC, 2 USDT, 3 WBTC, 4 WETH
    uint256 public optimal = 2; // this is the token we sell into, 0 DAI, 1 USDC, 2 USDT, 3 WBTC, 4 WETH
    IERC20 internal constant wbtc = IERC20(0x50b7545627a5162F82A992c33b87aDc75187B218);
    IERC20 internal constant weth = IERC20(0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB);
    IERC20 internal constant usdt = IERC20(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);
    IERC20 internal constant usdc = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    IERC20 internal constant dai = IERC20(0xd586E7F844cEa2F87f50152665BCbc2C279D8d70);
    IUniswapV2Router02 internal mainRouter = IUniswapV2Router02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4); // this is the router we swap with except for CRV
    IUniswapV2Router02 internal crvRouter = IUniswapV2Router02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4); // this is the router we swap CRV with, Sushi

    /* ========== CONSTRUCTOR ========== */

    constructor(address _vault, string memory _name) public StrategyCurveBase(_vault) {
        // You can set these parameters on deployment to whatever you want
        maxReportDelay = 2 days; // 2 days in seconds
        healthCheck = 0xf1e3dA291ae47FbBf625BB63D806Bf51f23A4aD2;

        // these are our standard approvals. want = Curve LP token
        want.approve(address(gauge), type(uint256).max);
        crv.approve(address(crvRouter), type(uint256).max);
        wavax.approve(address(mainRouter), type(uint256).max);
        weth.approve(address(mainRouter), type(uint256).max);

        // set our strategy's name
        stratName = _name;

        // these are our approvals and path specific to this contract
        wbtc.approve(address(curve), type(uint256).max);
        weth.approve(address(curve), type(uint256).max);
        usdt.safeApprove(address(curve), type(uint256).max);
        dai.approve(address(curve), type(uint256).max);
        usdc.approve(address(curve), type(uint256).max);

        // start off with dai
        targetToken = address(usdt);
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
                curve.add_liquidity([daiBalance, 0, 0, 0, 0], 0);
            }
        } else if (optimal == 1) {
            uint256 usdcBalance = usdc.balanceOf(address(this));
            if (usdcBalance > 0) {
                curve.add_liquidity([0, usdcBalance, 0, 0, 0], 0);
            }
        } else if (optimal == 2) {
            uint256 usdtBalance = usdt.balanceOf(address(this));
            if (usdtBalance > 0) {
                curve.add_liquidity([0, 0, usdtBalance, 0, 0], 0);
            }
        } else if (optimal == 3) {
            uint256 wbtcBalance = wbtc.balanceOf(address(this));
            if (wbtcBalance > 0) {
                curve.add_liquidity([0, 0, 0, wbtcBalance, 0], 0);
            }
        } else {
            uint256 wethBalance = weth.balanceOf(address(this));
            if (wethBalance > 0) {
                curve.add_liquidity([0, 0, 0, 0, wethBalance], 0);
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
    // Default is DAI, but can be set to USDC, USDT, WETH or WBTC as needed by strategist or governance.
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
        } else if (_optimal == 3) {
            targetToken = address(wbtc);
            optimal = 3;
        } else if (_optimal == 4) {
            targetToken = address(weth);
            optimal = 4;
        } else {
            revert("incorrect token");
        }
    }
}
