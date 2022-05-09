from itertools import count
from brownie import Wei, reverts, chain
import eth_abi
from brownie.convert import to_bytes
from useful_methods import genericStateOfStrat,genericStateOfVault
import random
import brownie
import pytest


def test_operation(strategy, usdc, user, poolToken, gov, amount, RELATIVE_APPROX, vault):
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

    # withdrawal
    vault.withdraw({"from": user})
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
    strategy, usdc, user, poolToken, gov, amount, RELATIVE_APPROX, vault
):
    # Deposit to the vault
    usdc.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert usdc.balanceOf(vault.address) == amount

    # Harvest 1: Send funds through the strategy
    chain.sleep(1)
    strategy.harvest()
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    # TODO: Add some code before harvest #2 to simulate earning yield

    # Harvest 2: Realize profit
    chain.sleep(1)
    strategy.harvest()
    chain.sleep(3600 * 6)  # 6 hrs needed for profits to unlock
    chain.mine(1)
    profit = usdc.balanceOf(vault.address)  # Profits go to vault
    # TODO: Uncomment the lines below
    # assert token.balanceOf(strategy) + profit > amount
    # assert vault.pricePerShare() > before_pps


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