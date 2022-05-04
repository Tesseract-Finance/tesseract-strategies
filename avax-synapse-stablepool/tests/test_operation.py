from itertools import count
from brownie import Wei, reverts, chain
import eth_abi
from brownie.convert import to_bytes
from useful_methods import genericStateOfStrat,genericStateOfVault
import random
import brownie


def test_strategy(strategy, usdc, user, poolToken, gov, amount, minichef_vault, vault):
    usdc.approve(vault, 2 ** 256 -1, {"from": user})
    vault.deposit(amount, {"from": user})
    lpBalanceBefore = poolToken.balanceOf(minichef_vault)
    userBefore = usdc.balanceOf(user)
    assert usdc.balanceOf(vault) == amount
    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.harvest({"from": gov})

    assert usdc.balanceOf(vault) == 0
    assert minichef_vault.balanceOf(strategy) > 0 
    lpBalanceAfter = poolToken.balanceOf(minichef_vault)

    assert lpBalanceAfter > lpBalanceBefore

    print(poolToken.balanceOf(minichef_vault))

    genericStateOfStrat(strategy, usdc, vault)
    genericStateOfVault(vault, usdc)

    chain.sleep(2592000)
    chain.mine(1)

    strategy.harvest({"from": gov})

    chain.sleep(21600)
    chain.mine(1)

    strategy.harvest({"from": gov})
    genericStateOfStrat(strategy, usdc, vault)
    genericStateOfVault(vault, usdc)

    print("\nEstimated APR: ", "{:.2%}".format(((vault.totalAssets()-2*1e18)*12)/(2*1e18)))
    chain.sleep(21600)
    chain.mine(1)

    vault.transferFrom(strategy, gov, vault.balanceOf(strategy), {"from": user})
    print("\nWithdraw")
    vault.withdraw(vault.balanceOf(user), {"from": user})
    balanceAfter = usdc.balanceOf(user)
    print("user profit: ", balanceAfter - userBefore)

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