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
    address public targetToken;
    address public poolToken;
    address public voter;

    uint256 public pid;
    uint256 public optimal = 2;

    IERC20 internal constant wmatic = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    
    IERC20 internal constant usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20 internal constant usdc = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 internal constant dai = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    IERC20 internal constant synapse = IERC20(0xf8F9efC0db77d8881500bb06FF5D6ABc3070E695);

    IUniswapV2Router02 public router;

    IMiniChefV2 public chef;

    constructor(
        address _vault,
        address _chef,
        address _reward,
        address _poolToken,
        address _router,
        uint _pid
    ) public BaseStrategy(_vault) {
         _initializeStrat(_chef, _reward, _router, _poolToken, _pid);
    }


    function _initializeStrat(
        address _chef,
        address _reward,
        address _router,
        address _poolToken,
        uint256 _pid
    ) internal {
        require(
            address(router) == address(0),"Minichef strategy already initialized"
        );
        chef = IMiniChefV2(_chef);
        router = IUniswapV2Router02(_router);
        pid = _pid;
        targetToken = address(usdt);
        poolToken = _poolToken;
        reward = _reward;

        wmatic.approve(address(router), type(uint256).max);
        IERC20(reward).approve(address(router), type(uint256).max);
        IERC20(poolToken).approve(address(chef), type(uint256).max);
        
    }


    function setOptimal(uint256 _optimal) external onlyAuthorized {
        if(_optimal == 0) {
            targetToken = address(dai);
            optimal = 0;
        } else if (_optimal == 1) {
            targetToken = address(usdc);
            optimal = 1;
        } else if (_optimal == 2){
            targetToken = address(usdt);
            optimal = 2;
        } else {
            revert("incorrect token");
        }
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


    function setVoter(address _voter) external onlyAuthorized {
        voter = _voter;
    }


    /**
     * @notice set the minichef for staking want
     * @param  _chef address of the staking contract
     * @dev    only callable by an authorised party
     */
    function setMiniChef(address _chef) external onlyAuthorized {
        chef = IMiniChefV2(_chef);
    }


    /**
     * @notice get the amount of lpToken stake on farm
     * @return balance of poolToken staked
     */
    function balanceOfStake() public view returns (uint256) {
        return chef.userInfo(pid, address(this)).amount;
    }

    /**
     * @notice get the amount of lpToken available on the strategy
     * @return balance of poolToken
     */
    function balanceOfLpToken() public view returns (uint256) {
        return IERC20(poolToken).balanceOf(address(this));
    }

    /**
     * @notice get the amount of reward Token available on the strategy
     * @return balance of synapse 
     */
    function balanceReward() public view returns (uint256) {
        return IERC20(reward).balanceOf(address(this));
    }


    function balanceOfOptimal() public view returns (uint256) {
        return IERC20(targetToken).balanceOf(address(this));
    }

    function name() external view override returns (string memory) {
        return "StrategySynapseRewards";
    }

    /**
     * @notice get the amount of assets denominated in want available to the contract, excluding 
     *         and token1 dust
     * @return balance of want + balance of stake
     */
    function estimatedTotalAssets() public view override returns (uint256) {
        return balanceOfLpToken().add(balanceOfStake());
    }


    // convert our keeper's eth cost into want, we don't need this anymore since we don't use baseStrategy harvestTrigger
    function nativeToWant(uint256 _ethAmount) public view override returns (uint256) {
        return _ethAmount;
    }

    /**
     * @notice get the claimable rewards from minichef
     * @return _reward synapse reward that is available for harvest
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
        protected[2] = address(wmatic);
        protected[3] = targetToken;
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
        uint256 lpBalance = balanceOfLpToken();
        uint256 stakeBal = balanceOfStake();
        if (_amountNeeded > lpBalance) {
            if (stakeBal > 0) {
                if (stakeBal > _amountNeeded.sub(lpBalance)) {
                    chef.withdraw(
                        pid,
                        _amountNeeded.sub(lpBalance),
                        address(this)
                    );
                } else {
                    chef.withdraw(pid, stakeBal, address(this));
                }
            } else {
                _loss = _amountNeeded.sub(lpBalance);
            }
        }
        _liquidatedAmount = Math.min(_amountNeeded, balanceOfLpToken());
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
            rewardToOptimal();
        }
        return balanceOfLpToken();
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

        uint256 optimalBefore = balanceOfOptimal();
        chef.harvest(pid, address(this));
        rewardToOptimal();

        _profit = balanceOfOptimal().sub(optimalBefore);
    }

    /**
     * @notice deploy any unused want
     * @param  _debtOutstanding the debt to send back to the vault
     * @dev    integral function for putting funds to work
     */
    function adjustPosition(uint256 _debtOutstanding) internal override {
        uint256 _lpTokenAvailable = balanceOfLpToken();
        if (emergencyExit) {
            return;
        }
        if (_debtOutstanding > _lpTokenAvailable) {
            return;
        }
        uint256 investAmount = _lpTokenAvailable.sub(_debtOutstanding);
        if (investAmount > 0) {
            chef.deposit(pid, investAmount, address(this));
        }
    }

    /**
     * @notice convert syn rewards to optimal
     * @dev    swap synapse rewards to target token
     */
    function rewardToOptimal() internal {
        uint256 rewardBalance = balanceReward();
        if(rewardBalance > 0) {
            _sell(address(reward), targetToken, rewardBalance);
        }
    }

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


    function prepareMigration(address _newStrategy) internal override {
        chef.withdrawAndHarvest(pid, balanceOfStake(), address(this));
        rewardToOptimal();
    }


}