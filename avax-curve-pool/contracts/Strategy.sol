// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./interfaces/curve.sol";
import "./interfaces/IERC20Extended.sol";

import "@tesrvaults/contracts/BaseStrategy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

contract Strategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    ICurveFi public curve;
    ICrvV3 public curveToken;
    VaultAPI public yvToken;

    uint256 public optimal = 2;
    uint256 public lastInvest; // default is 0
    uint256 public minTimePerInvest; // = 3600;
    uint256 public maxSingleInvest; // // 2 hbtc per hour default
    uint256 public slippageProtectionIn; // = 50; //out of 10000. 50 = 0.5%
    uint256 public slippageProtectionOut; // = 50; //out of 10000. 50 = 0.5%
    uint256 public constant DENOMINATOR = 10_000;
    string internal strategyName;

    uint8 private want_decimals;

    uint256 public curveId;
    uint256 public poolSize;
    address public metaToken;
    address public targetToken;
    bool public withdrawProtection;
    bool internal forceHarvestTriggerOnce; // only set this to true externally when we want to trigger our keepers to harvest for us
    uint256 public minHarvestCredit; // if we hit this amount of credit, harvest the strategy

    IERC20 internal constant wbtc = IERC20(0x50b7545627a5162F82A992c33b87aDc75187B218);
    IERC20 internal constant weth = IERC20(0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB);
    IERC20 internal constant usdt = IERC20(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);
    IERC20 internal constant usdc = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    IERC20 internal constant dai = IERC20(0xd586E7F844cEa2F87f50152665BCbc2C279D8d70);

    event Cloned(address indexed clone);

    constructor(
        address _vault,
        uint256 _maxSingleInvest,
        uint256 _minTimePerInvest,
        uint256 _slippageProtectionIn,
        address _curve,
        address _curveToken,
        address _yvToken,
        string memory _strategyName
    ) public BaseStrategy(_vault) {}

    function initialize(
        address _vault,
        address _strategist,
        uint256 _maxSingleInvest,
        uint256 _minTimePerInvest,
        uint256 _slippageProtectionIn,
        address _curve,
        address _curveToken,
        address _yvToken,
        string memory _strategyName
    ) external {
        //note: initialise can only be called once. in _initialize in BaseStrategy we have: require(address(want) == address(0), "Strategy already initialized");
        _initialize(_vault, _strategist, _strategist, _strategist);
        _initializeStrat(_maxSingleInvest, _minTimePerInvest, _slippageProtectionIn, _curve, _curveToken, _yvToken, _strategyName);
    }

    function _initializeStrat(
        uint256 _maxSingleInvest,
        uint256 _minTimePerInvest,
        uint256 _slippageProtectionIn,
        address _curve,
        address _curveToken,
        address _yvToken,
        string memory _strategyName
    ) internal {
        require(want_decimals == 0, "Already Initialize");

        curve = ICurveFi(_curve);
        maxSingleInvest = _maxSingleInvest;
        minTimePerInvest = _minTimePerInvest;
        slippageProtectionIn = _slippageProtectionIn;
        slippageProtectionOut = _slippageProtectionIn; // use In to start with to save on stack
        strategyName = _strategyName;

        yvToken = VaultAPI(_yvToken);
        curveToken = ICrvV3(_curveToken);

        _setupStatics();
    }

    function _setupStatics() internal {
        maxReportDelay = 86400;
        profitFactor = 1500;
        minReportDelay = 3600;
        debtThreshold = 100 * 1e18;
        withdrawProtection = true;
        want_decimals = IERC20Extended(address(want)).decimals();

        //deposit contract needs permissions
        if (metaToken != address(0)) {
            IERC20(metaToken).safeApprove(address(curve), type(uint256).max);
            curveToken.approve(address(curve), type(uint256).max);
        }

        curveToken.approve(address(yvToken), type(uint256).max);

        // these are our approvals and path specific to this contract
        wbtc.approve(address(curve), type(uint256).max);
        weth.approve(address(curve), type(uint256).max);
        usdt.safeApprove(address(curve), type(uint256).max);
        dai.approve(address(curve), type(uint256).max);
        usdc.approve(address(curve), type(uint256).max);

        targetToken = address(usdt);
    }

    function cloneCurve(
        address _vault,
        address _strategist,
        uint256 _maxSingleInvest,
        uint256 _minTimePerInvest,
        uint256 _slippageProtectionIn,
        address _curvePool,
        address _curveToken,
        address _yvToken,
        uint256 _poolSize,
        address _metaToken,
        bool _hasUnderlying,
        string memory _strategyName
    ) external returns (address payable newStrategy) {
        bytes20 addressBytes = bytes20(address(this));

        assembly {
            // EIP-1167 bytecode
            let clone_code := mload(0x40)
            mstore(clone_code, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone_code, 0x14), addressBytes)
            mstore(add(clone_code, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            newStrategy := create(0, clone_code, 0x37)
        }

        Strategy(newStrategy).initialize(
            _vault,
            _strategist,
            _maxSingleInvest,
            _minTimePerInvest,
            _slippageProtectionIn,
            _curvePool,
            _curveToken,
            _yvToken,
            _strategyName
        );

        emit Cloned(newStrategy);
    }

    function name() external view override returns (string memory) {
        return strategyName;
    }

    function updateMinTimePerInvest(uint256 _minTimePerInvest) public onlyAuthorized {
        minTimePerInvest = _minTimePerInvest;
    }

    function updateMaxSingleInvest(uint256 _maxSingleInvest) public onlyAuthorized {
        maxSingleInvest = _maxSingleInvest;
    }

    function updateSlippageProtectionIn(uint256 _slippageProtectionIn) public onlyAuthorized {
        slippageProtectionIn = _slippageProtectionIn;
    }

    function updateSlippageProtectionOut(uint256 _slippageProtectionOut) public onlyAuthorized {
        slippageProtectionOut = _slippageProtectionOut;
    }

    function updateWithdrawProtection(bool _withdrawProtection) public onlyAuthorized {
        withdrawProtection = _withdrawProtection;
    }

    function delegatedAssets() public view override returns (uint256) {
        return vault.strategies(address(this)).totalDebt;
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        uint256 totalCurveTokens = curveTokensInYVault().add(curveToken.balanceOf(address(this)));
        return IERC20(targetToken).balanceOf(address(this)).add(curveTokenToWant(totalCurveTokens));
    }

    function nativeToWant(uint256 _amtInWei) public view virtual override returns (uint256) {}

    // retruns value of total
    function curveTokenToWant(uint256 tokens) public view returns (uint256) {
        if (tokens == 0) {
            return 0;
        }

        return virtualPriceToWant().mul(tokens).div(1e18);
    }

    // we lose some precision here. but it shouldnt matter as we are underestimating
    function virtualPriceToWant() public view returns (uint256) {
        uint256 virtualPrice = curve.get_virtual_price();

        if (want_decimals < 18) {
            return virtualPrice.div(10**(uint256(uint8(18) - want_decimals)));
        } else {
            return virtualPrice;
        }
    }

    function curveTokensInYVault() public view returns (uint256) {
        uint256 balance = yvToken.balanceOf(address(this));

        if (yvToken.totalSupply() == 0) {
            //needed because of revert on priceperfullshare if 0
            return 0;
        }
        uint256 pricePerShare = yvToken.pricePerShare();
        //curve tokens are 1e18 decimals
        return balance.mul(pricePerShare).div(1e18);
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
        _debtPayment = _debtOutstanding;

        uint256 debt = vault.strategies(address(this)).totalDebt;
        uint256 currentValue = estimatedTotalAssets();
        uint256 wantBalance = want.balanceOf(address(this));

        if (debt < currentValue) {
            //profit
            _profit = currentValue.sub(debt);
        } else {
            _loss = debt.sub(currentValue);
        }

        uint256 toFree = _debtPayment.add(_profit);

        if (toFree > wantBalance) {
            toFree = toFree.sub(wantBalance);

            (, uint256 withdrawalLoss) = withdrawSome(toFree);
            //when we withdraw we can lose money in the withdrawal
            if (withdrawalLoss < _profit) {
                _profit = _profit.sub(withdrawalLoss);
            } else {
                _loss = _loss.add(withdrawalLoss.sub(_profit));
                _profit = 0;
            }

            wantBalance = want.balanceOf(address(this));

            if (wantBalance < _profit) {
                _profit = wantBalance;
                _debtPayment = 0;
            } else if (wantBalance < _debtPayment.add(_profit)) {
                _debtPayment = wantBalance.sub(_profit);
            }
        }
    }

    //safe to enter more than we have
    function withdrawSome(uint256 _amount) internal returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 wantBalanceBefore = IERC20(targetToken).balanceOf(address(this));

        //let's take the amount we need if virtual price is real. Let's add the
        uint256 virtualPrice = virtualPriceToWant();
        uint256 amountWeNeedFromVirtualPrice = _amount.mul(1e18).div(virtualPrice);

        uint256 crvBeforeBalance = curveToken.balanceOf(address(this)); //should be zero but just incase...

        uint256 pricePerFullShare = yvToken.pricePerShare();
        uint256 amountFromVault = amountWeNeedFromVirtualPrice.mul(1e18).div(pricePerFullShare);

        uint256 yBalance = yvToken.balanceOf(address(this));

        if (amountFromVault > yBalance) {
            amountFromVault = yBalance;
            //this is not loss. so we amend amount

            uint256 _amountOfCrv = amountFromVault.mul(pricePerFullShare).div(1e18);
            _amount = _amountOfCrv.mul(virtualPrice).div(1e18);
        }

        if (amountFromVault > 0) {
            yvToken.withdraw(amountFromVault);
            if (withdrawProtection) {
                //this tests that we liquidated all of the expected ytokens. Without it if we get back less then will mark it is loss
                require(yBalance.sub(yvToken.balanceOf(address(this))) >= amountFromVault.sub(1), "YVAULTWITHDRAWFAILED");
            }
        }

        uint256 toWithdraw = curveToken.balanceOf(address(this)).sub(crvBeforeBalance);

        if (toWithdraw > 0) {
            //if we have less than 18 decimals we need to lower the amount out
            uint256 maxSlippage = toWithdraw.mul(DENOMINATOR.sub(slippageProtectionOut)).div(DENOMINATOR);
            if (want_decimals < 18) {
                maxSlippage = maxSlippage.div(10**(uint256(uint8(18) - want_decimals)));
            }

            curve.remove_liquidity_one_coin(toWithdraw, curveId, maxSlippage);
        }

        uint256 diff = IERC20(targetToken).balanceOf(address(this)).sub(wantBalanceBefore);

        if (diff > _amount) {
            _liquidatedAmount = _amount;
        } else {
            _liquidatedAmount = diff;
            _loss = _amount.sub(diff);
        }
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        if (lastInvest.add(minTimePerInvest) > block.timestamp) {
            return;
        }

        // Invest the rest of the want
        uint256 _wantToInvest = Math.min(IERC20(targetToken).balanceOf(address(this)), maxSingleInvest);
        if (_wantToInvest == 0) {
            return;
        }

        uint256 expectedOut = _wantToInvest.mul(1e18).div(virtualPriceToWant());
        uint256 maxSlip = expectedOut.mul(DENOMINATOR.sub(slippageProtectionIn)).div(DENOMINATOR);

        // deposit our balance to Curve if we have any
        if (optimal == 0) {
            uint256 daiBalance = dai.balanceOf(address(this));
            if (daiBalance > 0) {
                curve.add_liquidity([daiBalance, 0, 0, 0, 0], maxSlip);
            }
        } else if (optimal == 1) {
            uint256 usdcBalance = usdc.balanceOf(address(this));
            if (usdcBalance > 0) {
                curve.add_liquidity([0, usdcBalance, 0, 0, 0], maxSlip);
            }
        } else if (optimal == 2) {
            uint256 usdtBalance = usdt.balanceOf(address(this));
            if (usdtBalance > 0) {
                curve.add_liquidity([0, 0, usdtBalance, 0, 0], maxSlip);
            }
        } else if (optimal == 3) {
            uint256 wbtcBalance = wbtc.balanceOf(address(this));
            if (wbtcBalance > 0) {
                curve.add_liquidity([0, 0, 0, wbtcBalance, 0], maxSlip);
            }
        } else {
            uint256 wethBalance = weth.balanceOf(address(this));
            if (wethBalance > 0) {
                curve.add_liquidity([0, 0, 0, 0, wethBalance], maxSlip);
            }
        }

        //now add to yearn
        yvToken.deposit();
        lastInvest = block.timestamp;
    }

    function liquidatePosition(uint256 _amountNeeded) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 wantBal = IERC20(targetToken).balanceOf(address(this));

        if (wantBal < _amountNeeded) {
            (_liquidatedAmount, _loss) = withdrawSome(_amountNeeded.sub(wantBal));
        }

        _liquidatedAmount = Math.min(_amountNeeded, _liquidatedAmount.add(wantBal));
    }

    function liquidateAllPositions() internal override returns (uint256 _amountFreed) {
        (_amountFreed, ) = liquidatePosition(1e36); //we can request a lot. dont use max because of overflow
    }

    function prepareMigration(address _newStrategy) internal override {
        yvToken.transfer(_newStrategy, yvToken.balanceOf(address(this)));
    }

    function protectedTokens() internal view override returns (address[] memory) {
        address[] memory protected = new address[](1);
        protected[0] = address(yvToken);

        return protected;
    }

    /* ========== SETTERS ========== */

    // These functions are useful for setting parameters of the strategy that may need to be adjusted.
    // Set optimal token to sell harvested funds for depositing to Curve.
    // Default is DAI, but can be set to USDC, USDT, WBTC, WETH as needed by strategist or governance.
    function setOptimal(uint256 _optimal) external onlyAuthorized {
        if (_optimal == 0) {
            targetToken = address(dai);
            optimal = 0;
            curveId = 0;
        } else if (_optimal == 1) {
            targetToken = address(usdc);
            optimal = 1;
            curveId = 1;
        } else if (_optimal == 2) {
            targetToken = address(usdt);
            optimal = 2;
            curveId = 2;
        } else if (_optimal == 3) {
            targetToken = address(wbtc);
            optimal = 3;
            curveId = 3;
        } else if (_optimal == 4) {
            targetToken = address(weth);
            optimal = 4;
            curveId = 4;
        } else {
            revert("incorrect token");
        }
    }

    ///@notice This allows us to manually harvest with our keeper as needed
    function setForceHarvestTriggerOnce(bool _forceHarvestTriggerOnce) external onlyAuthorized {
        forceHarvestTriggerOnce = _forceHarvestTriggerOnce;
    }

    ///@notice When our strategy has this much credit, harvestTrigger will be true.
    function setMinHarvestCredit(uint256 _minHarvestCredit) external onlyAuthorized {
        minHarvestCredit = _minHarvestCredit;
    }
}
