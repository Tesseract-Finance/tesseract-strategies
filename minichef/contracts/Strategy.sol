// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./interfaces/IMiniChefV2.sol";
import "./interfaces/IUniswapV2Router02.sol";


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

    uint public pid;

    IUniswapV2Router02 public router;

    IMiniChefV2 public chef;

    address public wNative;

    constructor(
        address _vault,
        address _chef,
        address _reward,
        address _router,
        uint _pid
    ) public BaseStrategy(_vault) {
         _initializeStrat(_chef, _reward, _router, _pid);
    }


    function _initializeStrat(
        address _chef,
        address _reward,
        address _router,
        uint256 _pid
    ) internal {
        require(
            address(router) == address(0),"Minichef strategy already initialized");
        
        chef = IMiniChefV2(_chef);
        router = IUniswapV2Router02(_router);
        pid = _pid;

        (address poolToken, , , ) = chef.poolInfo(pid);

        require(poolToken == address(want), "wrong pid");

        want.safeApprove(address(chef), uint256(-1));
        IERC20(reward).safeApprove(address(router), uint256(-1));
    }


    function setRouter(address _router) public onlyAuthorized {
        require(_router != address(0), "invalid address");
        router = IUniswapV2Router02(_router);
    }

    function name() external view override returns (string memory) {
        return "StrategySynapseRewards";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        (uint256 deposited, ) = chef.userInfo(pid, address(this));
        return want.balanceOf(address(this)).add(deposited);
    }

    function liquidateAllPositions() internal override returns (uint256) {
        (uint256 amount, ) = chef.userInfo(pid, address(this));
        if (amount > 0) {
            chef.withdrawAndHarvest(pid, amount, address(this));
        }
    }

    function pendingReward() 
        external
        view 
        returns (
           uint256 _reward
        )
    {
        _reward = chef.pendingSynapse(pid, address(this));
    }


    function rewardToWant() internal {
        uint256 rewardBalance = IERC20(reward).balanceOf(address(this));
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

    function protectedTokens() internal view override returns (address[] memory) {
        (address poolToken, , , ) = chef.poolInfo(pid);
        address[] memory protected = new address[](4);
        protected[0] = poolToken;
        protected[1] = reward;
        protected[2] = wNative;
        protected[3] = token;
        return protected;
    }

}