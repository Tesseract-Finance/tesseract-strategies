// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./interfaces/IMiniChefV2.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

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

    address public targetToken;
    // address public poolToken = IERC20(0x7479e1bc2f2473f9e78c89b4210eb6d55d33b645);

    uint256 public pid;
    uint256 public optimal = 2;

    string internal stratName;
    bool internal isOriginal = true;


    IERC20 internal constant wmatic = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IERC20 internal constant usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20 internal constant usdc = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 internal constant dai = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    IERC20 internal poolToken = IERC20(0x7479e1Bc2F2473f9e78c89B4210eb6d55d33b645);
    IERC20 public constant emissionToken = IERC20(0xf8F9efC0db77d8881500bb06FF5D6ABc3070E695);

    IUniswapV2Router02 public constant router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    IMiniChefV2 public constant chef = IMiniChefV2(0x7875Af1a6878bdA1C129a4e2356A3fD040418Be5);


    bool internal forceHarvestTriggerOnce; // only set this to true externally when we want to trigger our keepers to harvest for us
    uint256 public minHarvestCredit; // if we hit this amount of credit, harvest the strategy

    event Cloned(address indexed clone);


    constructor(
        address _vault,
        uint256 _pid,
        string memory _name
    ) public BaseStrategy(_vault) {
        _initializeStrat(_pid, _name);
    }

    function initialize(
        address _vault,
        address _strategist,
        address _rewards,
        address _keeper,
        uint256 _pid,
        string memory _name
    ) external {
        _initialize(_vault, _strategist, _rewards, _keeper);
        _initializeStrat(_pid, _name);
    }

    
    function _initializeStrat(
        uint256 _pid,
        string memory _name
    ) internal {
        // initialize variables
        maxReportDelay = 43200; // 1/2 day in seconds, if we hit this then harvestTrigger = True
        healthCheck = address(0xf13Cd6887C62B5beC145e30c38c4938c5E627fe0); // Fantom common health check
        // set our strategy's name
        stratName = _name;
        pid = _pid;
        require(chef.lpToken(pid) == address(want), "!wrong pid");

        // turn off our credit harvest trigger to start with
        minHarvestCredit = type(uint256).max;
        targetToken = address(usdt);
        wmatic.approve(address(router), type(uint256).max);
        want.approve(address(chef), type(uint256).max);
        emissionToken.approve(address(router), type(uint256).max);
    }

    /* ========== VIEWS ========== */

    function name() external view override returns (string memory) {
        return stratName;
    }
    // total balance want 
    function balanceOfWant() public view returns (uint256) {
        return want.balanceOf(address(this));
    }

    function balanceOfStaked() public view returns (uint256) {    
        return chef.userInfo(pid, address(this)).amount;
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        // look at our staked tokens and any free tokens sitting in the strategy
        return balanceOfStaked().add(balanceOfWant());
    }

    // convert our keeper's eth cost into want, we don't need this anymore since we don't use baseStrategy harvestTrigger
    function nativeToWant(uint256 _ethAmount) public view override returns (uint256) {
        return _ethAmount;
    }


    // our main trigger is regarding our DCA since there is low liquidity for our emissionToken
    function harvestTrigger(uint256 callCostinEth)
        public
        view
        override
        returns (bool)
    {
        StrategyParams memory params = vault.strategies(address(this));

        // harvest no matter what once we reach our maxDelay
        if (block.timestamp.sub(params.lastReport) > maxReportDelay) {
            return true;
        }

        // trigger if we want to manually harvest
        if (forceHarvestTriggerOnce) {
            return true;
        }

        // trigger if we have enough credit
        if (vault.creditAvailable() >= minHarvestCredit) {
            return true;
        }

        // otherwise, we don't harvest
        return false;
    }

    function cloneStrategy(
        address _vault,
        address _strategist,
        address _rewards,
        address _keeper,
        uint256 _pid,
        string memory _name
    ) external returns (address newStrategy) {
        // Copied from https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
        require(isOriginal);
        // Copied from https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
        bytes20 addressBytes = bytes20(address(this));
        assembly {
            // EIP-1167 bytecode
            let clone_code := mload(0x40)
            mstore(
                clone_code,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone_code, 0x14), addressBytes)
            mstore(
                add(clone_code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            newStrategy := create(0, clone_code, 0x37)
        }

        Strategy(newStrategy).initialize(
            _vault,
            _strategist,
            _rewards,
            _keeper,
            _pid,
            _name
        );

        emit Cloned(newStrategy);
    }

    // These functions are useful for setting parameters of the strategy that may need to be adjusted.
    // Set optimal token to sell harvested funds for depositing to Curve.
    // Default is DAI, but can be set to USDC, USDT as needed by strategist or governance.
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

    ///@notice Only do this if absolutely necessary; as assets will be withdrawn but rewards won't be claimed.
    function emergencyWithdraw() external onlyEmergencyAuthorized {
        chef.emergencyWithdraw(pid, address(this));
    }

    
    
    function protectedTokens() internal view override returns (address[] memory) {
    }




    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        uint256 totalAssets = want.balanceOf(address(this));
        if (_amountNeeded > totalAssets) {
            uint256 amountToFree = _amountNeeded.sub(totalAssets);

            uint256 deposited = balanceOfStaked();
            if (deposited < amountToFree) {
                amountToFree = deposited;
            }
            if (deposited > 0) {
                chef.withdraw(pid, amountToFree, address(this));
            }

            _liquidatedAmount = want.balanceOf(address(this));
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    // withdraw all funds, harvest for synase and sell for optimal token
    function liquidateAllPositions() internal override returns (uint256) {
        uint256 amount = balanceOfStaked();
        if (amount > 0) {
            chef.withdrawAndHarvest(
                pid, 
                amount, 
                address(this)
            );
            return balanceOfWant();
        }
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        // claim our rewards
        chef.harvest(pid, address(this));

        // if we have emissionToken to sell, then sell some of it
        uint256 emissionTokenBalance = emissionToken.balanceOf(address(this));
        if (emissionTokenBalance > 0) {
            // sell our emissionToken
            rewardToOptimal();
        }

        // get assets balance
        uint256 assets = estimatedTotalAssets();
        uint256 wantBal = balanceOfWant();

        uint256 debt = vault.strategies(address(this)).totalDebt;
        uint256 amountToFree;

        // this would only happen if the chef somehow lost funds or was drained
        uint256 chefHoldings = want.balanceOf(address(chef));
        uint256 stakedBalance = balanceOfStaked();
        if (chefHoldings < stakedBalance) {
            amountToFree = chefHoldings;
            liquidatePosition(amountToFree);
            _debtPayment = balanceOfWant();
            _loss = stakedBalance.sub(_debtPayment);
            return (_profit, _loss, _debtPayment);
        }

        if (assets > debt) {
            _debtPayment = _debtOutstanding;
            _profit = assets - debt;

            amountToFree = _profit.add(_debtPayment);

            if (amountToFree > 0 && wantBal < amountToFree) {
                liquidatePosition(amountToFree);

                uint256 newLoose = want.balanceOf(address(this));

                //if we dont have enough money adjust _debtOutstanding and only change profit if needed
                if (newLoose < amountToFree) {
                    if (_profit > newLoose) {
                        _profit = newLoose;
                        _debtPayment = 0;
                    } else {
                        _debtPayment = Math.min(
                            newLoose - _profit,
                            _debtPayment
                        );
                    }
                }
            }
        } else {
            //serious loss should never happen but if it does lets record it accurately
            _loss = debt - assets;
        }

        // we're done harvesting, so reset our trigger if we used it
        forceHarvestTriggerOnce = false;
    }



    function prepareMigration(address _newStrategy) internal override {
        uint256 stakedBalance = balanceOfStaked();
        if (stakedBalance > 0) {
            chef.withdraw(pid, stakedBalance, address(this));
        }

        // send our claimed emissionToken to the new strategy
        emissionToken.safeTransfer(
            _newStrategy,
            emissionToken.balanceOf(address(this))
        );
    }


    function adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }
        // send all of our want tokens to be deposited
        uint256 toInvest = balanceOfWant();
        // stake only if we have something to stake
        if (toInvest > 0) {
            chef.deposit(pid, toInvest, address(this));
        }
    }


    // sell rewards token to targetTokens
    function rewardToOptimal() internal {
        uint256 rewardBalance = emissionToken.balanceOf(address(this));
        if (rewardBalance > 0) {
            // swap reward for optimal on sushiswap
            _sell(
                address(emissionToken), 
                targetToken, 
                rewardBalance
            );
        }
    }


    // swap rewards to target using sushiswap router
    function _sell(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amount
    ) internal {
        address[] memory path;

        if (_tokenFrom == address(wmatic)) {
            path = new address[](2);
            path[0] = _tokenFrom;
            path[1] = _tokenTo;
        } else if (_tokenTo == address(wmatic)) {
            path = new address[](2);
            path[0] = _tokenFrom;
            path[1] = _tokenTo;
        } else {
            path = new address[](3);
            path[0] = _tokenFrom;
            path[1] = address(wmatic);
            path[2] = _tokenTo;
        }

        router.swapExactTokensForTokens(_amount, 0, path, address(this), now);
    }


    /* ========== SETTERS ========== */

    ///@notice This allows us to manually harvest with our keeper as needed
    function setForceHarvestTriggerOnce(bool _forceHarvestTriggerOnce)
        external
        onlyAuthorized
    {
        forceHarvestTriggerOnce = _forceHarvestTriggerOnce;
    }

    ///@notice When our strategy has this much credit, harvestTrigger will be true.
    function setMinHarvestCredit(uint256 _minHarvestCredit)
        external
        onlyAuthorized
    {
        minHarvestCredit = _minHarvestCredit;
    }

}