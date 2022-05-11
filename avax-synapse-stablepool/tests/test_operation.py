from itertools import count
from brownie import Wei, reverts, chain
import eth_abi
from brownie.convert import to_bytes
from useful_methods import genericStateOfStrat,genericStateOfVault
import random
import brownie
import pytest


def test_operation(strategy, usdc, user, poolToken, gov, amount, RELATIVE_APPROX, vault, minichef_strategy, minichef_keeper):
    # Deposit to the vault
    user_balance_before = usdc.balanceOf(user)
    usdc.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert usdc.balanceOf(vault.address) == amount

    # harvest
    chain.sleep(1)
    strategy.harvest()
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    # tend()
    strategy.tend()

    minichef_strategy.harvest({"from": minichef_keeper})
    chain.sleep(3600 * 6)  # 6 hrs needed for profits to unlock
    chain.mine(1)

    strategy.harvest()

    # withdrawal
    vault.withdraw(amount, {"from": user})
    assert (
        pytest.approx(usdc.balanceOf(user), rel=RELATIVE_APPROX) == user_balance_before
    )



def test_emergency_exit(
    strategy, usdc, user, poolToken, gov, amount, RELATIVE_APPROX, vault
):

    # Deposit to the vault
    usdc.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    chain.sleep(1)
    strategy.harvest()
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    # set emergency and exit
    strategy.setEmergencyExit()
    chain.sleep(1)
    strategy.harvest()
    assert strategy.estimatedTotalAssets() < amount


def test_profitable_harvest(
    strategy, usdc, user, poolToken, gov, amount, RELATIVE_APPROX, vault, minichef_strategy, minichef_keeper, minichef_vault
):
    # Deposit to the vault
    usdc.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert usdc.balanceOf(vault.address) == amount

    before_pps = vault.pricePerShare()

    # Harvest 1: Send funds through the strategy
    chain.sleep(1)
    strategy.harvest()

    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    minichef_strategy.harvest({"from": minichef_keeper})
    chain.sleep(86400 * 30)
    chain.mine(1)
    minichef_strategy.harvest({"from": minichef_keeper})
    chain.sleep(86400)
    chain.mine(1)

    # Harvest 2: Realize profit
    tx = strategy.harvest()
    print(tx.events["Harvested"])
    chain.sleep(3600 * 6)  # 6 hrs needed for profits to unlock
    chain.mine(1)
    profit = usdc.balanceOf(vault.address)  # Profits go to vault
    print(profit)
    assert vault.pricePerShare() > before_pps
    



def test_change_debt(
    strategy, usdc, user, poolToken, gov, amount, RELATIVE_APPROX, vault
):
    # Deposit to the vault and harvest
    usdc.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    vault.updateStrategyDebtRatio(strategy.address, 5_000, {"from": gov})
    chain.sleep(1)
    strategy.harvest()
    half = int(amount / 2)

    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == half

    vault.updateStrategyDebtRatio(strategy.address, 10_000, {"from": gov})
    chain.sleep(1)
    strategy.harvest()
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount


def test_reduce_limit(strategy, usdc, user, poolToken, gov, amount, minichef_vault, vault):
    usdc.approve(vault, 2 ** 256 - 1, {"from": user} )
    vault.deposit(amount, {"from": user})
    strategy.setDoHealthCheck(False, {"from": gov})
    chain.sleep(2592000)
    chain.mine(1)
    strategy.harvest({'from': gov})

    genericStateOfStrat(strategy, usdc, vault)
    genericStateOfVault(vault, usdc)

    vault.revokeStrategy(strategy, {'from': gov})

    chain.sleep(2592000)
    chain.mine(1)
    strategy.harvest({'from': gov})

    genericStateOfStrat(strategy, usdc, vault)
    genericStateOfVault(vault, usdc)


def test_triggers(
    strategy, usdc, user, poolToken, gov, amount, RELATIVE_APPROX, vault
):
    # Deposit to the vault and harvest
    usdc.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    vault.updateStrategyDebtRatio(strategy.address, 5_000, {"from": gov})
    chain.sleep(1)
    strategy.harvest()

    strategy.harvestTrigger(0)
    strategy.tendTrigger(0)


def test_strategy( strategy, usdc, user, poolToken, gov, amount, RELATIVE_APPROX, vault, minichef_strategy, minichef_keeper, minichef_vault, strategist):
    decimals = usdc.decimals()
    usdc.approve(vault.address, amount, {"from": user})
    balanceBefore = usdc.balanceOf(user);
    vault.deposit(amount, {"from": user})
    
    chain.sleep(1)
    strategy.harvest()

    chain.sleep(86400)
    chain.mine(1)

    minichef_strategy.harvest({"from": minichef_keeper})
    chain.sleep(86400 * 30)
    chain.mine(1)
    minichef_strategy.harvest({"from": minichef_keeper})
    chain.sleep(86400)
    strategy.harvest()

    genericStateOfStrat(strategy, usdc, vault)
    genericStateOfVault(vault, usdc)

    chain.sleep(21600)
    chain.mine(1)
    
    print("\nEstimated APR: ", "{:.2%}".format(((vault.totalAssets()-2*1e18)*12)/(2*1e18)))

  

    vault.transferFrom(strategy, strategist, vault.balanceOf(strategy), {"from": strategist})
    print("\nWithdraw")

    vault.withdraw(vault.balanceOf(user), user, 100, {"from": user})
    # vault.withdraw(vault.balanceOf(strategist), strategist, 100, {"from": strategist})

    balanceAfter = usdc.balanceOf(user)
    print("Whale profit: ", (usdc.balanceOf(user) - balanceBefore)/1e18)
    print("Whale profit %: ", "{:.2%}".format(((usdc.balanceOf(usdc) - balanceBefore)/amount)*12))