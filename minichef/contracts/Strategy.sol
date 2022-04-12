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

    address public reward;
    address public token;
    address public poolToken;

    uint public pid;

    IUniswapV2Router02 public router;

    IMiniChefV2 public chef;

    address public wNative;

    constructor(
        address _vault,
        address _chef,
        address _reward,
        address _poolToken,
        address _router,
        address _token,
        uint _pid
    ) public BaseStrategy(_vault) {
         _initializeStrat(_chef, _reward, _router,  _poolToken,_token, _pid);
    }


    function _initializeStrat(
        address _chef,
        address _reward,
        address _router,
        address _poolToken,
        address _token,
        uint256 _pid
    ) internal {
        require(
            address(router) == address(0),"Minichef strategy already initialized");
        
        chef = IMiniChefV2(_chef);
        router = IUniswapV2Router02(_router);
        pid = _pid;
        token = _token;
        poolToken = _poolToken;
        require(poolToken == address(want), "wrong pid");

        want.safeApprove(address(chef), uint256(-1));
        IERC20(reward).safeApprove(address(router), uint256(-1));
        IERC20(token).safeApprove(token, uint256(-1));
    }

    function balanceOfToken() public view returns (uint256) {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        return tokenBalance;
    }

    function balanceOfStake() public view returns (uint256) {
        return chef.userInfo(pid, address(this)).amount;
    }


    function setRouter(address _router) public onlyAuthorized {
        require(_router != address(0), "invalid address");
        router = IUniswapV2Router02(_router);
    }
    
    
    /**
     * @notice set the unique id for the pool used for staking want
     * @param  _pid unique id of the pool in minichefv2
     * @dev    only callable by an authorised party
     */
    function setPid(uint256 _pid) external onlyAuthorized {
        pid = _pid;
    }


    /**
     * @notice set the minichef for staking want
     * @param  _chef address of the staking contract
     * @dev    only callable by an authorised party
     */
    function setMiniChef(address _chef) external onlyAuthorized {
        chef = IMiniChefV2(_chef);
    }





    function name() external view override returns (string memory) {
        return "StrategySynapseRewards";
    }

    /**
     * @notice get the amount of assets denominated in want available to the contract, excluding token0, xSushi
     *         and token1 dust
     * @return balance of want + balance of stake
     */
    function estimatedTotalAssets() public view override returns (uint256) {
        uint256 deposited = chef.userInfo(pid, address(this)).amount;
        uint256 wantBal = IERC20(poolToken).balanceOf(address(this));
        return wantBal.add(deposited);
    }



    function nativeToWant(uint256 _amtInWei) public view override returns (uint256) {}


    /**
     * @notice get the claimable rewards from minichef
     * @return _reward sushi reward that is available for harvest
     */

    function pendingReward() 
        external
        view 
        returns (
           uint256 _reward
        )
    {
        _reward = chef.pendingSynapse(pid, address(this));
    }


    /**
     * @notice tokens that cant be touched by sweep
     * @return addresses of untouchable tokens
     */
    function protectedTokens() internal view override returns (address[] memory) {
        address[] memory protected = new address[](4);
        protected[0] = poolToken;
        protected[1] = reward;
        protected[2] = wNative;
        protected[3] = token;
        return protected;
    }



    /**
     * @notice liquidate an amount of assets to return to the vault
     * @param  _amountNeeded amount to liquidate
     * @return _liquidatedAmount amount that has been liquidated
     * @return _loss if there are insufficient funds then this represents the loss for the vault to make up
     */
    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        uint256 wantBal = IERC20(poolToken).balanceOf(address(this));
        uint256 stakeBal = balanceOfStake();
        if (_amountNeeded > wantBal) {
            if (stakeBal > 0) {
                if (stakeBal > _amountNeeded.sub(wantBal)) {
                    chef.withdraw(
                        pid,
                        _amountNeeded.sub(wantBal),
                        address(this)
                    );
                } else {
                    chef.withdraw(pid, stakeBal, address(this));
                }
            } else {
                _loss = _amountNeeded.sub(wantBal);
            }
        }
        _liquidatedAmount = Math.min(_amountNeeded, IERC20(poolToken).balanceOf(address(this)));
        _loss = _amountNeeded.sub(_liquidatedAmount);
    }

    /**
     * @notice liquidate all assets
     * @return amount of want in the contract
     */
    function liquidateAllPositions() internal override returns (uint256) {
        uint256 amount = chef.userInfo(pid, address(this)).amount;
        if (amount > 0) {
            chef.withdrawAndHarvest(pid, amount, address(this));
            rewardToWant();
        }
        return IERC20(poolToken).balanceOf(address(this));
    }


    /**
     * @notice get the amount of assets in the contract, excluding token0 and token1 dust
     * @param  _debtOutstanding the debt to send back to the vault
     * @return _profit the profit of the strategy against the last harvest
     * @return _loss the loss of the strategy against the last harvest
     * @return _debtPayment the debt to return to the vault
     */
    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        if (_debtOutstanding > 0) {
            uint256 _amountFreed = 0;
            (_amountFreed, _loss) = liquidatePosition(_debtOutstanding);
            _debtPayment = Math.min(_amountFreed, _debtOutstanding);
        }

        uint256 wantBefore = IERC20(poolToken).balanceOf(address(this));
        chef.harvest(pid, address(this));
        rewardToWant();

        _profit = IERC20(poolToken).balanceOf(address(this)).sub(wantBefore);
    }

    /**
     * @notice deploy any unused want
     * @param  _debtOutstanding the debt to send back to the vault
     * @dev    integral function for putting funds to work
     */
    function adjustPosition(uint256 _debtOutstanding) internal override {
        uint256 _wantAvailable = IERC20(poolToken).balanceOf(address(this));
        if (emergencyExit) {
            return;
        }
        if (_debtOutstanding > _wantAvailable) {
            return;
        }
        uint256 investAmount = _wantAvailable.sub(_debtOutstanding);
        if (investAmount > 0) {
            chef.deposit(pid, investAmount, address(this));
        }
    }


    function rewardToWant() internal {
        uint256 rewardBalance = IERC20(reward).balanceOf(address(this));
        if(rewardBalance > 0) {
            _sell(address(reward), token, rewardBalance);
        }
    }

    function _sell(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amount
    ) internal {
        address[] memory path;

        if (_tokenFrom == wNative) {
            path = new address[](2);
            path[0] = _tokenFrom;
            path[1] = _tokenTo;
        } else if (_tokenTo == wNative) {
            path = new address[](2);
            path[0] = _tokenFrom;
            path[1] = _tokenTo;
        } else {
            path = new address[](3);
            path[0] = _tokenFrom;
            path[1] = wNative;
            path[2] = _tokenTo;
        }

        router.swapExactTokensForTokens(_amount, 0, path, address(this), now);
    }


    function prepareMigration(address _newStrategy) internal override {
        chef.withdrawAndHarvest(pid, balanceOfStake(), address(this));
        rewardToWant();
    }


}