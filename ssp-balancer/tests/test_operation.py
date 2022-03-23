import brownie
from brownie import Contract
import pytest
import util



def test_operation(
        chain, accounts, token, vault, strategy, user, strategist, amount, RELATIVE_APPROX
):
    # Deposit to the vault
    print("Strategy Name:", strategy.name())
    user_balance_before = token.balanceOf(user)
    token.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert token.balanceOf(vault.address) == amount

    # harvest
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    # tend()
    strategy.tend({"from": strategist})

    # withdrawal
    vault.withdraw(vault.balanceOf(user), user, 10, {"from": user})
    assert (pytest.approx(token.balanceOf(user), rel=RELATIVE_APPROX) == user_balance_before)


def test_emergency_exit(
        chain, accounts, token, vault, strategy, user, strategist, amount, RELATIVE_APPROX
):
    # Deposit to the vault
    token.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    # set emergency and exit
    strategy.setEmergencyExit()
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    assert strategy.estimatedTotalAssets() < amount


def test_profitable_harvest(
        chain, token, vault, strategy, user, strategist, amount, RELATIVE_APPROX, bal, bal_whale, management
):
    # Deposit to the vault
    token.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert token.balanceOf(vault.address) == amount

    # Harvest 1: Send funds through the strategy
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    before_pps = vault.pricePerShare()
    util.airdrop_rewards(strategy, bal, bal_whale)

    # Harvest 2: Realize profit
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    chain.sleep(3600 * 6)  # 6 hrs needed for profits to unlock
    chain.mine(1)
    profit = token.balanceOf(vault.address)  # Profits go to vault

    assert strategy.estimatedTotalAssets() + profit > amount
    assert vault.pricePerShare() > before_pps


def test_deposit_all(chain, token, vault, strategy, user, strategist, amount, RELATIVE_APPROX, bal, bal_whale, gov, pool):
    # Deposit to the vault
    token.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert token.balanceOf(vault.address) == amount

    # Harvest 1: Send funds through the strategy
    chain.sleep(1)

    strategy.harvest({"from": strategist})
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    chain.sleep(strategy.minDepositPeriod() + 1)
    chain.mine(1)
    while strategy.tendTrigger(0) == True:
        strategy.tend({'from': gov})
        util.stateOfStrat("tend", strategy, token)
        assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount
        chain.sleep(strategy.minDepositPeriod() + 1)
        chain.mine(1)

    before_pps = vault.pricePerShare()
    util.airdrop_rewards(strategy, bal, bal_whale)

    # Harvest 2: Realize profit
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    chain.sleep(3600 * 6)  # 6 hrs needed for profits to unlock
    chain.mine(1)
    profit = token.balanceOf(vault.address)  # Profits go to vault

    slippageIn = amount * strategy.maxSlippageIn() / 10000
    assert strategy.estimatedTotalAssets() + profit > (amount - slippageIn)
    assert vault.pricePerShare() > before_pps

    vault.updateStrategyDebtRatio(strategy.address, 5_000, {"from": gov})
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    util.stateOfStrat("after harvest 5000", strategy, token)

    half = int(amount / 2)
    # profits
    assert strategy.estimatedTotalAssets() >= half - slippageIn / 2


def test_change_debt(
        chain, gov, token, vault, strategy, user, strategist, amount, RELATIVE_APPROX, bal, bal_whale
):
    # Deposit to the vault and harvest
    token.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    vault.updateStrategyDebtRatio(strategy.address, 5_000, {"from": gov})
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    half = int(amount / 2)

    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == half

    vault.updateStrategyDebtRatio(strategy.address, 10_000, {"from": gov})
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    util.stateOfStrat("before airdrop", strategy, token)
    util.airdrop_rewards(strategy, bal, bal_whale)
    util.stateOfStrat("after airdrop", strategy, token)

    vault.updateStrategyDebtRatio(strategy.address, 5_000, {"from": gov})
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    util.stateOfStrat("after harvest 5000", strategy, token)

    # compounded slippage
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == half

    vault.updateStrategyDebtRatio(strategy.address, 0, {"from": gov})
    chain.sleep(1)
    strategy.harvest({"from": strategist})
    util.stateOfStrat("after harvest", strategy, token)

    assert token.balanceOf(vault.address) >= amount or pytest.approx(token.balanceOf(vault.address),
                                                                     rel=RELATIVE_APPROX) >= amount


def test_sweep(gov, vault, strategy, token, user, amount, weth, weth_amout):
    # Strategy want token doesn't work
    token.transfer(strategy, amount, {"from": user})
    assert token.address == strategy.want()
    assert token.balanceOf(strategy) > 0
    with brownie.reverts("!want"):
        strategy.sweep(token, {"from": gov})

    # Vault share token doesn't work
    with brownie.reverts("!shares"):
        strategy.sweep(vault.address, {"from": gov})

    # # Protected token doesn't work
    # for i in range(strategy.numRewards()):
    #     with brownie.reverts("!protected"):
    #         strategy.sweep(strategy.rewardTokens(i), {"from": gov})

    before_balance = weth.balanceOf(gov)
    weth.transfer(strategy, weth_amout, {"from": user})
    assert weth.address != strategy.want()
    assert weth.balanceOf(user) == 0
    strategy.sweep(weth, {"from": gov})
    assert weth.balanceOf(gov) == weth_amout + before_balance

def test_eth_sweep(chain, token, vault, strategy, user, strategist, gov):
    strategist.transfer(strategy,1e18)
    with brownie.reverts():
        strategy.sweepETH({"from": strategist})

    eth_balance = gov.balance()
    strategy.sweepETH({"from": gov})
    assert gov.balance() > eth_balance

def test_triggers(
        chain, gov, vault, strategy, token, amount, user, weth, weth_amout, strategist, bal, bal_whale, token_whale
):
    # Deposit to the vault and harvest
    token.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    vault.updateStrategyDebtRatio(strategy.address, 5_000, {"from": gov})
    chain.sleep(1)
    strategy.harvest({"from": strategist})

    assert strategy.tendTrigger(0) == False
    chain.sleep(strategy.minDepositPeriod() + 1)
    chain.mine(1)
    print(strategy.balanceOfWant())
    assert strategy.tendTrigger(0) == True


def test_rewards(
        strategy, strategist, gov
):
    # added in setup
    assert strategy.numRewards() == 1
    strategy.delistAllRewards({'from': gov})
    assert strategy.numRewards() == 0

def test_unbalance_deposit(chain, token, vault, strategy, user, strategist, amount, RELATIVE_APPROX, bal,
                                  bal_whale, token2_whale, token2, usdc_whale, gov, pool, balancer_vault):
    # added in setup
    assert strategy.numRewards() == 1
    strategy.delistAllRewards({'from': gov})
    assert strategy.numRewards() == 0

    token.approve(vault.address, 2**256-1, {"from": user})
    vault.deposit(amount, {"from": user})
    assert token.balanceOf(vault.address) == amount


    print(f'pool rate before whale swap: {pool.getRate()}')
    pooled = balancer_vault.getPoolTokens(pool.getPoolId())[1][strategy.tokenIndex()]
    token.approve(balancer_vault, 2 ** 256 - 1, {'from': usdc_whale})
    chain.snapshot()
    singleSwap = (
        pool.getPoolId(), # PoolID
        0,              # Kind --- #0 = GIVEN_IN, 1 = GIVEN_OUT
        token,          # asset in
        token2,         # asset out
        pooled / 1.5,   # amount -- here we increase usdc side of the pool dramatically
        b'0x0'          # user data
    )
    chain.snapshot()
    balancer_vault.swap(
            singleSwap,             # swap struct
            (                       # fund struct
                usdc_whale,     # sender
                False,          # fromInternalBalance
                usdc_whale,     # recipient
                False           # toInternalBalance
            ),
            token.balanceOf(usdc_whale),   # token limit
            2**256-1,                   # Deadline
            {'from': usdc_whale}
    )
    print(f'pool rate after whale swap: {pool.getRate()}')

    with brownie.reverts("BAL#208"):
        tx = strategy.harvest({"from": strategist}) # Error Code BAL#208 BPT_OUT_MIN_AMOUNT - Slippage/front-running protection check failed on a pool join


def test_unbalanced_pool_withdraw(chain, token, vault, strategy, user, strategist, amount, RELATIVE_APPROX, bal,
                                  bal_whale, token2_whale, token2, gov, pool, balancer_vault):
    # Deposit to the vault
    token.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert token.balanceOf(vault.address) == amount

    # Harvest 1: Send funds through the strategy
    chain.sleep(1)
    print(f'pool rate: {pool.getRate()}')

    strategy.harvest({"from": strategist})
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    chain.sleep(strategy.minDepositPeriod() + 1)
    chain.mine(1)

    # iterate to get all the funds in
    while strategy.tendTrigger(0) == True:
        strategy.tend({'from': gov})
        util.stateOfStrat("tend", strategy, token)
        assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount
        chain.sleep(strategy.minDepositPeriod() + 1)
        chain.mine(1)

    print(f'pool rate: {pool.getRate()}')
    tokens = balancer_vault.getPoolTokens(pool.getPoolId())[0]
    token2Index = 0
    if (tokens[0] == token2):
        token2Index = 0
    elif tokens[1] == token2:
        token2Index = 1
    elif tokens[2] == token2:
        token2Index = 2

    util.stateOfStrat("after deposit all    ", strategy, token)
    pooled = balancer_vault.getPoolTokens(pool.getPoolId())[1][strategy.tokenIndex()]
    print(balancer_vault.getPoolTokens(pool.getPoolId()))
    print(f'pooled: {pooled}')

    # simulate bad pool state by whale to swap out 98% of one side of the pool so pool only has 2% of the original want
    token2.approve(balancer_vault, 2 ** 256 - 1, {'from': token2_whale})
    singleSwap = (pool.getPoolId(), 1, token2, token, pooled * 0.98, b'0x0')
    balancer_vault.swap(
        singleSwap,
        (token2_whale, False, token2_whale, False),
        token2.balanceOf(token2_whale),
        2**256-1,
        {'from': token2_whale}
    )

    print(balancer_vault.getPoolTokens(pool.getPoolId()))
    print(f'pool rate: {pool.getRate()}')

    # now pool is in a bad state low-want
    print(f'pool state: {balancer_vault.getPoolTokens(pool.getPoolId())}')

    # withdraw half to see how much we get back, it should be lossy. Assert that our slippage check prevents this
    with brownie.reverts():
        vault.withdraw(vault.balanceOf(user) / 2, user, 10000, {"from": user})
    old_slippage = strategy.maxSlippageOut()

    # loosen the slippage check to let the lossy withdraw go through
    strategy.setParams(10000, 10000, strategy.maxSingleDeposit(), strategy.minDepositPeriod(), {'from': gov})
    vault.withdraw(vault.balanceOf(user) / 2, user, 10000, {"from": user})
    print(f'user balance: {token.balanceOf(user)}')
    print(f'user lost: {amount / 2 - token.balanceOf(user)}')
    util.stateOfStrat("after lossy withdraw", strategy, token)

    # make sure principal is still as expected, aka loss wasn't socialized
    assert strategy.estimatedTotalAssets() >= amount / 2 * (10000 - old_slippage) / 10000
