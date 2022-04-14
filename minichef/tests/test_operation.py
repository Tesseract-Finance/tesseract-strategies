import brownie
import pytest
from brownie import Contract, chain

def test_operation(
    chain,
    poolToken,
    vault,
    strategy,
    user,
    amount,
    chef,
    gov,
    pid
):
    # deposit to the vault
    assert poolToken.balanceOf(user) == amount 
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount

    # harvest
    chain.sleep(1)
    chain.mine(10)
    strategy.harvest({"from": gov})
    # check if fund are transfered to strategy 
    assert poolToken.balanceOf(vault) == 0
    assert strategy.estimatedTotalAssets() == amount

    # tend()
    strategy.tend()

    # user withdraw
    vault.withdraw({"from": user})
    assert poolToken.balanceOf(user) == amount
    assert strategy.estimatedTotalAssets() == 0


def test_emergency(
    chain,
    strategy,
    poolToken,
    amount,
    pid,
    chef,
    user,
    vault
):
    # deposit to the vault
    assert poolToken.balanceOf(user) == amount 
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount

    # set emergency and exit
    strategy.setEmergencyExit()
    strategy.harvest()
    assert poolToken.balanceOf(strategy) < amount


def test_emergeny_withdraw(
    strategy,
    poolToken,
    amount,
    user,
    vault,
    chef,
    pid,
    gov
):
    # deposit to the vault
    assert poolToken.balanceOf(user) == amount
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount

    strategy.harvest()
    # check if pool token as been staked
    assert poolToken.balanceOf(strategy) == 0
    assert chef.userInfo(pid,  strategy)[0] == amount

    # emergency Exit staking
    strategy.emergencyWithdrawal({"from": gov})
    assert chef.userInfo(pid,  strategy)[0] == 0
    assert poolToken.balanceOf(strategy) == amount



def test_profitable_harvest(
    chain,
    poolToken,
    amount,
    user,
    chef,
    pid,
    gov,
    strategy,
    vault,
    synapseToken,
    usdt,
    whale
):

    # deposit to the vault
    assert poolToken.balanceOf(user) == amount
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount

    chain.sleep(1)
    chain.mine(10)

    # let whale deposit
    amount2 = 20_000e18
    poolToken.approve(vault, amount2, {"from": whale})
    vault.deposit(amount2, {"from": whale})

    chain.sleep(1)
    strategy.harvest()
    
    assert strategy.estimatedTotalAssets() == amount + amount2

    chain.sleep(3600 * 12) # wait 12 hours for profit to unlock

    chain.mine(1)

    assert usdt.balanceOf(strategy) == 0
    chef.updatePool(pid, {"from": gov})
    strategy.harvest()
    assert usdt.balanceOf(strategy) > 0