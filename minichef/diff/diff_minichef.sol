diff --git a/Strategy0xDAOStaker/contracts/Strategy0xDAOStaker.sol b/Tesseract/avax/tesseract-strategies/minichef/contracts/Strategy.sol
index 48e4d58..18a7ca3 100644
--- a/Strategy0xDAOStaker/contracts/Strategy0xDAOStaker.sol
+++ b/Tesseract/avax/tesseract-strategies/minichef/contracts/Strategy.sol
@@ -1,120 +1,53 @@
 // SPDX-License-Identifier: AGPL-3.0
-// Feel free to change the license, but this is what we use
-
-// Feel free to change this version of Solidity. We support >=0.6.0 <0.7.0;
 pragma solidity 0.6.12;
 pragma experimental ABIEncoderV2;
 
-// These are the core Yearn libraries
-import {
-    BaseStrategy,
-    StrategyParams
-} from "@yearnvaults/contracts/BaseStrategy.sol";
-import {
-    SafeERC20,
-    SafeMath,
-    IERC20,
-    Address
-} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
-import "@openzeppelin/contracts/math/Math.sol";
-
-interface ICurveFi {
-    function exchange(
-        int128 from,
-        int128 to,
-        uint256 _from_amount,
-        uint256 _min_to_amount
-    ) external;
-
-    function exchange_underlying(
-        int128 from,
-        int128 to,
-        uint256 _from_amount,
-        uint256 _min_to_amount
-    ) external;
-}
-
-interface IUniswapV2Router02 {
-    function swapExactTokensForTokens(
-        uint256 amountIn,
-        uint256 amountOutMin,
-        address[] calldata path,
-        address to,
-        uint256 deadline
-    ) external returns (uint256[] memory amounts);
-
-    function getAmountsOut(uint256 amountIn, address[] calldata path)
-        external
-        view
-        returns (uint256[] memory amounts);
-}
-
-interface ChefLike {
-    function deposit(uint256 _pid, uint256 _amount) external;
+import "./interfaces/IMiniChefV2.sol";
+import "./interfaces/IUniswapV2Router02.sol";
+import "./interfaces/IUniswapV2Factory.sol";
+import "./interfaces/curve.sol";
 
-    function withdraw(uint256 _pid, uint256 _amount) external; // use amount = 0 for harvesting rewards
+import "@tesrvaults/contracts/BaseStrategy.sol";
 
-    function emergencyWithdraw(uint256 _pid) external;
-
-    function poolInfo(uint256 _pid)
-        external
-        view
-        returns (
-            address lpToken,
-            uint256 allocPoint,
-            uint256 lastRewardTime,
-            uint256 accOXDPerShare
-        );
+import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
+import "@openzeppelin/contracts/math/SafeMath.sol";
+import "@openzeppelin/contracts/utils/Address.sol";
+import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
+import "@openzeppelin/contracts/math/Math.sol";
 
-    function userInfo(uint256 _pid, address user)
-        external
-        view
-        returns (uint256 amount, uint256 rewardDebt);
-}
 
-contract Strategy0xDAOStaker is BaseStrategy {
+contract Strategy is BaseStrategy {
     using SafeERC20 for IERC20;
     using Address for address;
     using SafeMath for uint256;
 
-    /* ========== STATE VARIABLES ========== */
-
-    ChefLike public constant masterchef =
-        ChefLike(0xa7821C3e9fC1bF961e280510c471031120716c3d);
-    IERC20 public constant emissionToken =
-        IERC20(0xc165d941481e68696f43EE6E99BFB2B23E0E3114); // the token we receive for staking, 0XD
-
-    // swap stuff
-    address internal constant spookyRouter =
-        0xF491e7B69E4244ad4002BC14e878a34207E38c29;
-    ICurveFi internal constant mimPool =
-        ICurveFi(0x2dd7C9371965472E5A5fD28fbE165007c61439E1); // Curve's MIM-USDC-USDT pool
-    ICurveFi internal constant daiPool =
-        ICurveFi(0x27E611FD27b276ACbd5Ffd632E5eAEBEC9761E40); // Curve's USDC-DAI pool
-
-    // tokens
-    IERC20 internal constant wftm =
-        IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
-    IERC20 internal constant weth =
-        IERC20(0x74b23882a30290451A17c44f4F05243b6b58C76d);
-    IERC20 internal constant wbtc =
-        IERC20(0x321162Cd933E2Be498Cd2267a90534A804051b11);
-    IERC20 internal constant dai =
-        IERC20(0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E);
-    IERC20 internal constant usdc =
-        IERC20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
-    IERC20 internal constant mim =
-        IERC20(0x82f0B8B456c1A451378467398982d4834b6829c1);
-
-    uint256 public pid; // the pool ID we are staking for
-
-    string internal stratName; // we use this for our strategy's name on cloning
+    address public targetToken;
+
+    uint256 public pid;
+    uint256 public optimal = 2;
+
+    string internal stratName;
     bool internal isOriginal = true;
 
+    IERC20 internal constant wavax = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
+    IERC20 internal constant usdt = IERC20(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);
+    IERC20 internal constant usdc = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
+    IERC20 internal constant dai = IERC20(0xd586E7F844cEa2F87f50152665BCbc2C279D8d70);
+    IERC20 internal constant nusd = IERC20(0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46);
+    IERC20 internal poolToken = IERC20(0xCA87BF3ec55372D9540437d7a86a7750B42C02f4);
+    IERC20 public constant emissionToken = IERC20(0x1f1E7c893855525b303f99bDF5c3c05Be09ca251);
+
+    IUniswapV2Router02 public constant router = IUniswapV2Router02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4); // traderjoe router
+    IMiniChefV2 public constant chef = IMiniChefV2(0x3a01521F8E7F012eB37eAAf1cb9490a5d9e18249);
+
+    ICurveFi public constant curve = ICurveFi(0xED2a7edd7413021d440b09D654f3b87712abAB66);
+
+
     bool internal forceHarvestTriggerOnce; // only set this to true externally when we want to trigger our keepers to harvest for us
     uint256 public minHarvestCredit; // if we hit this amount of credit, harvest the strategy
 
-    /* ========== CONSTRUCTOR ========== */
+    event Cloned(address indexed clone);
+
 
     constructor(
         address _vault,
@@ -124,12 +57,96 @@ contract Strategy0xDAOStaker is BaseStrategy {
         _initializeStrat(_pid, _name);
     }
 
-    /* ========== CLONING ========== */
+    function initialize(
+        address _vault,
+        address _strategist,
+        address _rewards,
+        address _keeper,
+        uint256 _pid,
+        string memory _name
+    ) external {
+        _initialize(_vault, _strategist, _rewards, _keeper);
+        _initializeStrat(_pid, _name);
+    }
 
-    event Cloned(address indexed clone);
+    
+    function _initializeStrat(
+        uint256 _pid,
+        string memory _name
+    ) internal {
+        // initialize variables
+        maxReportDelay = 86400; // 1 day in seconds, if we hit this then harvestTrigger = True
+        healthCheck = address(0x6fD0f710f30d4dC72840aE4e263c22d3a9885D3B); // avax common health check
+        // set our strategy's name
+        stratName = _name;
+        pid = _pid;
+        require(chef.lpToken(pid) == address(want), "!wrong pid");
+
+        // turn off our credit harvest trigger to start with
+        minHarvestCredit = type(uint256).max;
+        targetToken = address(usdt);
+        wavax.approve(address(router), type(uint256).max);
+        want.approve(address(chef), type(uint256).max);
+        emissionToken.approve(address(router), type(uint256).max);
+        usdt.safeApprove(address(curve), type(uint256).max);
+        usdc.approve(address(curve), type(uint256).max);
+        dai.approve(address(curve), type(uint256).max);
+    }
+
+    /* ========== VIEWS ========== */
+
+    function name() external view override returns (string memory) {
+        return stratName;
+    }
+    // total balance want 
+    function balanceOfWant() public view returns (uint256) {
+        return want.balanceOf(address(this));
+    }
+
+    function balanceOfStaked() public view returns (uint256) {    
+        return chef.userInfo(pid, address(this)).amount;
+    }
+
+    function estimatedTotalAssets() public view override returns (uint256) {
+        // look at our staked tokens and any free tokens sitting in the strategy
+        return balanceOfStaked().add(balanceOfWant());
+    }
+
+    // convert our keeper's eth cost into want, we don't need this anymore since we don't use baseStrategy harvestTrigger
+    function nativeToWant(uint256 _ethAmount) public view override returns (uint256) {
+        return _ethAmount;
+    }
+
+
+    // our main trigger is regarding our DCA since there is low liquidity for our emissionToken
+    function harvestTrigger(uint256 callCostinEth)
+        public
+        view
+        override
+        returns (bool)
+    {
+        StrategyParams memory params = vault.strategies(address(this));
+
+        // harvest no matter what once we reach our maxDelay
+        if (block.timestamp.sub(params.lastReport) > maxReportDelay) {
+            return true;
+        }
+
+        // trigger if we want to manually harvest
+        if (forceHarvestTriggerOnce) {
+            return true;
+        }
+
+        // trigger if we have enough credit
+        if (vault.creditAvailable() >= minHarvestCredit) {
+            return true;
+        }
 
-    // we use this to clone our original strategy to other vaults
-    function clone0xDAOStaker(
+        // otherwise, we don't harvest
+        return false;
+    }
+
+    function cloneStrategy(
         address _vault,
         address _strategist,
         address _rewards,
@@ -137,8 +154,8 @@ contract Strategy0xDAOStaker is BaseStrategy {
         uint256 _pid,
         string memory _name
     ) external returns (address newStrategy) {
-        require(isOriginal);
         // Copied from https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
+        require(isOriginal);
         bytes20 addressBytes = bytes20(address(this));
         assembly {
             // EIP-1167 bytecode
@@ -155,7 +172,7 @@ contract Strategy0xDAOStaker is BaseStrategy {
             newStrategy := create(0, clone_code, 0x37)
         }
 
-        Strategy0xDAOStaker(newStrategy).initialize(
+        Strategy(newStrategy).initialize(
             _vault,
             _strategist,
             _rewards,
@@ -167,63 +184,72 @@ contract Strategy0xDAOStaker is BaseStrategy {
         emit Cloned(newStrategy);
     }
 
-    // this will only be called by the clone function above
-    function initialize(
-        address _vault,
-        address _strategist,
-        address _rewards,
-        address _keeper,
-        uint256 _pid,
-        string memory _name
-    ) public {
-        _initialize(_vault, _strategist, _rewards, _keeper);
-        _initializeStrat(_pid, _name);
+    // These functions are useful for setting parameters of the strategy that may need to be adjusted.
+    // Set optimal token to sell harvested funds for depositing to Curve.
+    // Default is DAI, but can be set to USDC, USDT as needed by strategist or governance.
+    function setOptimal(uint256 _optimal) external onlyAuthorized {
+        if (_optimal == 0) {
+            targetToken = address(dai);
+            optimal = 0;
+        } else if (_optimal == 1) {
+            targetToken = address(usdc);
+            optimal = 1;
+        } else if (_optimal == 2) {
+            targetToken = address(usdt);
+            optimal = 2;
+        } else if (_optimal == 3) {
+            targetToken = address(nusd);
+            optimal = 3;
+        }
     }
 
-    // this is called by our original strategy, as well as any clones
-    function _initializeStrat(uint256 _pid, string memory _name) internal {
-        // initialize variables
-        maxReportDelay = 43200; // 1/2 day in seconds, if we hit this then harvestTrigger = True
-        healthCheck = address(0xf13Cd6887C62B5beC145e30c38c4938c5E627fe0); // Fantom common health check
-
-        // set our strategy's name
-        stratName = _name;
+    ///@notice Only do this if absolutely necessary; as assets will be withdrawn but rewards won't be claimed.
+    function emergencyWithdraw() external onlyEmergencyAuthorized {
+        chef.emergencyWithdraw(pid, address(this));
+    }
 
-        // make sure that we used the correct pid
-        pid = _pid;
-        (address poolToken, , , ) = masterchef.poolInfo(pid);
-        require(poolToken == address(want), "wrong pid");
+    
+    
+    function protectedTokens() internal view override returns (address[] memory) {
+    }
 
-        // turn off our credit harvest trigger to start with
-        minHarvestCredit = type(uint256).max;
 
-        // add approvals on all tokens
-        usdc.approve(spookyRouter, type(uint256).max);
-        usdc.approve(address(mimPool), type(uint256).max);
-        usdc.approve(address(daiPool), type(uint256).max);
-        want.approve(address(masterchef), type(uint256).max);
-        emissionToken.approve(spookyRouter, type(uint256).max);
-    }
 
-    /* ========== VIEWS ========== */
 
-    function name() external view override returns (string memory) {
-        return stratName;
-    }
+    function liquidatePosition(uint256 _amountNeeded)
+        internal
+        override
+        returns (uint256 _liquidatedAmount, uint256 _loss)
+    {
+        uint256 totalAssets = want.balanceOf(address(this));
+        if (_amountNeeded > totalAssets) {
+            uint256 amountToFree = _amountNeeded.sub(totalAssets);
 
-    function balanceOfWant() public view returns (uint256) {
-        return want.balanceOf(address(this));
-    }
+            uint256 deposited = balanceOfStaked();
+            if (deposited < amountToFree) {
+                amountToFree = deposited;
+            }
+            if (deposited > 0) {
+                chef.withdraw(pid, amountToFree, address(this));
+            }
 
-    function balanceOfStaked() public view returns (uint256) {
-        (uint256 stakedInMasterchef, ) =
-            masterchef.userInfo(pid, address(this));
-        return stakedInMasterchef;
+            _liquidatedAmount = want.balanceOf(address(this));
+        } else {
+            _liquidatedAmount = _amountNeeded;
+        }
     }
 
-    function estimatedTotalAssets() public view override returns (uint256) {
-        // look at our staked tokens and any free tokens sitting in the strategy
-        return balanceOfStaked().add(balanceOfWant());
+    // withdraw all funds
+    function liquidateAllPositions() internal override returns (uint256) {
+        uint256 amount = balanceOfStaked();
+        if (amount > 0) {
+            chef.withdrawAndHarvest(
+                pid, 
+                amount, 
+                address(this)
+            );
+            return balanceOfWant();
+        }
     }
 
     /* ========== MUTATIVE FUNCTIONS ========== */
@@ -238,26 +264,36 @@ contract Strategy0xDAOStaker is BaseStrategy {
         )
     {
         // claim our rewards
-        masterchef.withdraw(pid, 0);
+        chef.harvest(pid, address(this));
 
         // if we have emissionToken to sell, then sell some of it
         uint256 emissionTokenBalance = emissionToken.balanceOf(address(this));
         if (emissionTokenBalance > 0) {
             // sell our emissionToken
-            _sell(emissionTokenBalance);
+            rewardToOptimal();
         }
-
+        // reinvest optimal
+        uint256[] memory data = new uint256[](4);
+        data[0] = nusd.balanceOf(address(this));
+        data[1] = dai.balanceOf(address(this));
+        data[2] = usdc.balanceOf(address(this));
+        data[3] = usdt.balanceOf(address(this));
+
+        if (data[0] > 0 || data[1] > 0 || data[2] > 0 || data[3] > 0) {
+            curve.addLiquidity(data, 0, now);
+        }
+        // get assets balance
         uint256 assets = estimatedTotalAssets();
         uint256 wantBal = balanceOfWant();
 
         uint256 debt = vault.strategies(address(this)).totalDebt;
         uint256 amountToFree;
 
-        // this would only happen if the masterchef somehow lost funds or was drained
-        uint256 masterchefHoldings = want.balanceOf(address(masterchef));
+        // this would only happen if the chef somehow lost funds or was drained
+        uint256 chefHoldings = want.balanceOf(address(chef));
         uint256 stakedBalance = balanceOfStaked();
-        if (masterchefHoldings < stakedBalance) {
-            amountToFree = masterchefHoldings;
+        if (chefHoldings < stakedBalance) {
+            amountToFree = chefHoldings;
             liquidatePosition(amountToFree);
             _debtPayment = balanceOfWant();
             _loss = stakedBalance.sub(_debtPayment);
@@ -297,54 +333,12 @@ contract Strategy0xDAOStaker is BaseStrategy {
         forceHarvestTriggerOnce = false;
     }
 
-    function adjustPosition(uint256 _debtOutstanding) internal override {
-        if (emergencyExit) {
-            return;
-        }
-        // send all of our want tokens to be deposited
-        uint256 toInvest = balanceOfWant();
-        // stake only if we have something to stake
-        if (toInvest > 0) {
-            masterchef.deposit(pid, toInvest);
-        }
-    }
-
-    function liquidatePosition(uint256 _amountNeeded)
-        internal
-        override
-        returns (uint256 _liquidatedAmount, uint256 _loss)
-    {
-        uint256 totalAssets = want.balanceOf(address(this));
-        if (_amountNeeded > totalAssets) {
-            uint256 amountToFree = _amountNeeded.sub(totalAssets);
-
-            (uint256 deposited, ) =
-                ChefLike(masterchef).userInfo(pid, address(this));
-            if (deposited < amountToFree) {
-                amountToFree = deposited;
-            }
-            if (deposited > 0) {
-                ChefLike(masterchef).withdraw(pid, amountToFree);
-            }
-
-            _liquidatedAmount = want.balanceOf(address(this));
-        } else {
-            _liquidatedAmount = _amountNeeded;
-        }
-    }
 
-    function liquidateAllPositions() internal override returns (uint256) {
-        uint256 stakedBalance = balanceOfStaked();
-        if (stakedBalance > 0) {
-            masterchef.withdraw(pid, stakedBalance);
-        }
-        return balanceOfWant();
-    }
 
     function prepareMigration(address _newStrategy) internal override {
         uint256 stakedBalance = balanceOfStaked();
         if (stakedBalance > 0) {
-            masterchef.withdraw(pid, stakedBalance);
+            chef.withdraw(pid, stakedBalance, address(this));
         }
 
         // send our claimed emissionToken to the new strategy
@@ -354,123 +348,60 @@ contract Strategy0xDAOStaker is BaseStrategy {
         );
     }
 
-    ///@notice Only do this if absolutely necessary; as assets will be withdrawn but rewards won't be claimed.
-    function emergencyWithdraw() external onlyEmergencyAuthorized {
-        masterchef.emergencyWithdraw(pid);
-    }
 
-    // sell from reward token to want
-    function _sell(uint256 _amount) internal {
-        // sell our emission token for usdc
-        address[] memory emissionTokenPath = new address[](2);
-        emissionTokenPath[0] = address(emissionToken);
-        emissionTokenPath[1] = address(usdc);
-
-        IUniswapV2Router02(spookyRouter).swapExactTokensForTokens(
-            _amount,
-            uint256(0),
-            emissionTokenPath,
-            address(this),
-            block.timestamp
-        );
-
-        if (address(want) == address(usdc)) {
+    function adjustPosition(uint256 _debtOutstanding) internal override {
+        if (emergencyExit) {
             return;
         }
-
-        // sell our USDC for want
-        uint256 usdcBalance = usdc.balanceOf(address(this));
-        if (address(want) == address(wftm)) {
-            // sell our usdc for want with spooky
-            address[] memory usdcSwapPath = new address[](2);
-            usdcSwapPath[0] = address(usdc);
-            usdcSwapPath[1] = address(want);
-
-            IUniswapV2Router02(spookyRouter).swapExactTokensForTokens(
-                usdcBalance,
-                uint256(0),
-                usdcSwapPath,
-                address(this),
-                block.timestamp
-            );
-        } else if (address(want) == address(weth)) {
-            // sell our usdc for want with spooky
-            address[] memory usdcSwapPath = new address[](3);
-            usdcSwapPath[0] = address(usdc);
-            usdcSwapPath[1] = address(wftm);
-            usdcSwapPath[2] = address(weth);
-
-            IUniswapV2Router02(spookyRouter).swapExactTokensForTokens(
-                usdcBalance,
-                uint256(0),
-                usdcSwapPath,
-                address(this),
-                block.timestamp
-            );
-        } else if (address(want) == address(dai)) {
-            // sell our usdc for want with curve
-            daiPool.exchange(1, 0, usdcBalance, 0);
-        } else if (address(want) == address(mim)) {
-            // sell our usdc for want with curve
-            mimPool.exchange(2, 0, usdcBalance, 0);
-        } else if (address(want) == address(wbtc)) {
-            // sell our usdc for want with spooky
-            address[] memory usdcSwapPath = new address[](3);
-            usdcSwapPath[0] = address(usdc);
-            usdcSwapPath[1] = address(wftm);
-            usdcSwapPath[2] = address(wbtc);
-
-            IUniswapV2Router02(spookyRouter).swapExactTokensForTokens(
-                usdcBalance,
-                uint256(0),
-                usdcSwapPath,
-                address(this),
-                block.timestamp
-            );
+        // send all of our want tokens to be deposited
+        uint256 toInvest = balanceOfWant();
+        // stake only if we have something to stake
+        if (toInvest > 0) {
+            chef.deposit(pid, toInvest, address(this));
         }
     }
 
-    function protectedTokens()
-        internal
-        view
-        override
-        returns (address[] memory)
-    {}
 
-    // our main trigger is regarding our DCA since there is low liquidity for our emissionToken
-    function harvestTrigger(uint256 callCostinEth)
-        public
-        view
-        override
-        returns (bool)
-    {
-        StrategyParams memory params = vault.strategies(address(this));
-
-        // harvest no matter what once we reach our maxDelay
-        if (block.timestamp.sub(params.lastReport) > maxReportDelay) {
-            return true;
+    // sell rewards token to targetTokens
+    function rewardToOptimal() internal {
+        uint256 rewardBalance = emissionToken.balanceOf(address(this));
+        if (rewardBalance > 0) {
+            // swap reward for optimal
+            _sell(
+                address(emissionToken), 
+                targetToken, 
+                rewardBalance
+            );
         }
+    }
 
-        // trigger if we want to manually harvest
-        if (forceHarvestTriggerOnce) {
-            return true;
-        }
 
-        // trigger if we have enough credit
-        if (vault.creditAvailable() >= minHarvestCredit) {
-            return true;
+    // swap rewards to target using assigned router
+    function _sell(
+        address _tokenFrom,
+        address _tokenTo,
+        uint256 _amount
+    ) internal {
+        address[] memory path;
+
+        if (_tokenFrom == address(wavax)) {
+            path = new address[](2);
+            path[0] = _tokenFrom;
+            path[1] = _tokenTo;
+        } else if (_tokenTo == address(wavax)) {
+            path = new address[](2);
+            path[0] = _tokenFrom;
+            path[1] = _tokenTo;
+        } else {
+            path = new address[](3);
+            path[0] = _tokenFrom;
+            path[1] = address(wavax);
+            path[2] = _tokenTo;
         }
 
-        // otherwise, we don't harvest
-        return false;
+        router.swapExactTokensForTokens(_amount, 0, path, address(this), now);
     }
 
-    function ethToWant(uint256 _amtInWei)
-        public
-        view
-        override
-        returns (uint256)
-    {}
 
     /* ========== SETTERS ========== */
 
@@ -489,4 +420,5 @@ contract Strategy0xDAOStaker is BaseStrategy {
     {
         minHarvestCredit = _minHarvestCredit;
     }
-}
+
+}
\ No newline at end of file
