// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "./interfaces/curve.sol";
import "./interfaces/yearn.sol";
import {BaseStrategy, StrategyParams} from "@tesrvaults/contracts/BaseStrategy.sol";

abstract contract StrategyCurveBase is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */
    // these should stay the same across different wants.

    // Curve stuff
    IGauge public immutable gauge; // Curve gauge contract, tokenized, held by strategy

    // keepCRV stuff
    address public voter;
    uint256 public keepCRV; // the percentage of CRV we re-lock for boost (in basis points)
    uint256 internal constant FEE_DENOMINATOR = 10000; // this means all of our fee values are in basis points

    IERC20 internal constant crv = IERC20(0x172370d5Cd63279eFa6d502DAB29171933a610AF);
    IERC20 internal constant wmatic = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    bool internal forceHarvestTriggerOnce; // only set this to true externally when we want to trigger our keepers to harvest for us

    string internal stratName; // set our strategy name here

    /* ========== CONSTRUCTOR ========== */

    constructor(address _vault, address _gauge) public BaseStrategy(_vault) {
        gauge = IGauge(_gauge);
    }

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
