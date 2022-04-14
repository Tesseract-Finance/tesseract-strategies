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
    address public poolToken;
    address public reward;

    uint256 public pid;
    uint256 public optimal;

    IERC20 internal constant wmatic = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IERC20 internal constant usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20 internal constant usdc = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 internal constant dai = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);

    IUniswapV2Router02 public router;
    IMiniChefV2 public chef;

    event Cloned(address indexed clone);


    constructor(
        address _vault,
        address _chef,
        address _poolToken,
        address _reward,
        address _router,
        uint256 _pid
    ) public BaseStrategy(_vault) {
        _initializeStrat(_vault, _chef, _poolToken, _reward, _router, _pid);
    }

    function initialize(
        address _vault,
        address _chef,
        address _poolToken,
        address _reward,
        address _router,
        address _strategist,
        address _rewards,
        address _keeper,
        uint256 _pid
    ) external {
        _initialize(_vault, _strategist, _rewards, _keeper);
        _initializeStrat(_vault, _chef, _poolToken, _reward, _router, _pid);
    }

    
    function _initializeStrat(
        address _vault,
        address _chef,
        address _poolToken,
        address _reward,
        address _router,
        uint256 _pid
    ) internal {
        require(
            address(router) == address(0), "Strategy already initialized"
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

    // getter

    function name() external view override returns (string memory) {
        return "StrategySynapseRewards";
    }

    function balanceOptimal() public view returns (uint256) {
        return IERC20(targetToken).balanceOf(address(this));
    }

    function balanceOfLpToken() public view returns (uint256) {
        return IERC20(poolToken).balanceOf(address(this));
    }

    function balanceOfStaked() public view returns (uint256) {
        return chef.userInfo(pid, address(this)).amount;
    }

    function balanceOfReward() public view returns (uint256) {
        return IERC20(reward).balanceOf(address(this));
    }


    function estimatedTotalAssets() public view override returns (uint256) {
        return balanceOfLpToken().add(balanceOfStaked());
    }

    // convert our keeper's eth cost into want, we don't need this anymore since we don't use baseStrategy harvestTrigger
    function nativeToWant(uint256 _ethAmount) public view override returns (uint256) {
        return _ethAmount;
    }


    function cloneStrategy(
        address _vault,
        address _chef,
        address _poolToken,
        address _reward,
        address _router,
        address _strategist,
        address _rewards,
        address _keeper,
        uint256 _pid
    ) external returns (address newStrategy) {
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

        Strategy(newStrategy).initialize(_vault, _chef, _poolToken, _reward, _router, _strategist, _rewards, _keeper, _pid);    
        emit Cloned(newStrategy);
    }

    // exit from chef liquidity
    function emergencyWithdrawal() external onlyAuthorized {
        chef.emergencyWithdraw(pid, address(this));
    }

    function protectedTokens() internal view override returns (address[] memory) {
        address[] memory protected = new address[](4);
        protected[0] = poolToken;
        protected[1] = reward;
        protected[2] =  address(wmatic);
        protected[3] = targetToken;
        return protected;
    }




    function liquidatePosition(uint256 _amountNeeded) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        uint256 lpTokenBalance = balanceOfLpToken();
        uint256 stakedBalance = balanceOfStaked();

        if (_amountNeeded > lpTokenBalance) {
            if(stakedBalance > 0) {
                if(stakedBalance > _amountNeeded.sub(lpTokenBalance)) {
                    chef.withdraw(
                        pid,
                        _amountNeeded.sub(lpTokenBalance), 
                        address(this)
                    );
                } else {
                    chef.withdraw(
                        pid,
                        stakedBalance,
                        address(this)
                    );
                }
            }  else {
                    _loss = _amountNeeded.sub(lpTokenBalance);
            }
        }
        _liquidatedAmount = Math.min(_amountNeeded, balanceOfLpToken());
        _loss = _amountNeeded.sub(_liquidatedAmount);
    }


    function liquidateAllPositions() internal override returns (uint256) {
        uint256 amount = balanceOfStaked();
        if (amount > 0) {
            chef.withdrawAndHarvest(
                pid, 
                amount, 
                address(this)
            );
            // sell collected reward to optimal
            rewardToOptimal();
        }
    }

    function prepareReturn(uint256 _debtOustanding) 
        internal 
        override 
        returns (
            uint256 _profit, 
            uint256 _loss, 
            uint256 _debtPayment
        ) 
    {
        if (_debtOustanding > 0) {
            uint256 _amounToFree;
            (_amountToFree, _loss) = liquidatePosition(_debtOustanding);
            _debtPayment = Math.min(_amountToFree, _debtOustanding);
        }

        // get balance Of optimal
        uint256 optimalBefore = balanceOptimal();
        chef.harvest(pid, address(this));
        // sell gain to optimal
        rewardToOptimal();
        _profit = balanceOptimal().sub(optimalBefore);
    }


    function prepareMigration(address _newStrategy) internal override {
        chef.withdrawAndHarvest(pid, balanceOfStaked(), address(this));
        rewardToOptimal();
    }


    function adjustPosition(uint256 _debtOutstanding) internal override {
        uint256 lpTokenBalance = balanceOfLpToken();
        if (emergencyExit) {
            return;
        }
        if (_debtOutstanding >= lpTokenBalance) {
            return;
        }
        uint256 investAmount = lpTokenBalance.sub(_debtOutstanding);
        // restake lpToken if investAmount > 0
        if (investAmount > 0) {
            chef.deposit(pid, investAmount, address(this));
        }
    }



    function rewardToOptimal() internal {
        uint256 rewardBalance = balanceOfReward();
        if (rewardBalance > 0) {
            // swap reward for optimal on sushiswap
            _sell(
                reward, 
                targetToken, 
                rewardBalance
            );
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

}