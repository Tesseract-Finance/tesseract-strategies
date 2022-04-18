from tarfile import USTAR_FORMAT
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
    pid,
    usdt
):
    # deposit to the vault
    assert poolToken.balanceOf(user) == amount 
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount

    # harvest
    chain.sleep(1)
    chain.mine(10)
    strategy.setDoHealthCheck(False, {"from": gov})
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
    vault,
    gov
):
    # deposit to the vault
    assert poolToken.balanceOf(user) == amount 
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount

    # set emergency and exit
    chain.sleep(1)
    chain.mine(10)
    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.setEmergencyExit()
    strategy.harvest({"from": gov})
    assert poolToken.balanceOf(strategy) < amount


def test_emergeny_withdraw(
    strategy,
    poolToken,
    amount,
    user,
    vault,
    chef,
    pid,
    gov,
    chain
):
    # deposit to the vault
    assert poolToken.balanceOf(user) == amount
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount

    chain.sleep(1)
    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.harvest({"from": gov})
    # check if pool token as been staked
    assert poolToken.balanceOf(strategy) == 0
    assert chef.userInfo(pid,  strategy)[0] == amount

    # emergency Exit staking
    strategy.emergencyWithdraw({"from": gov})
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
    # chef.updatePool(pid, {"from": gov})
    poolToken.approve(vault, 100_000e18, {"from": whale})
    vault.deposit(100_000e18, {"from": whale})
    strategy.harvest({"from": gov})
    assert usdt.balanceOf(strategy) > 0


def test_update_optimal(
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
    whale,
    dai
): 
    # user deposit to vault
    assert poolToken.balanceOf(user) == amount
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount

    chain.sleep(1)
    chain.mine(10)
    # send the fund to the strategy and stake to farm
    strategy.harvest({"from": gov})
    assert poolToken.balanceOf(strategy) == 0

    # wait to make profit
    chain.sleep(86400)
    chain.mine(1)
    # harvest to take profit
    strategy.harvest({"from": gov})
    assert usdt.balanceOf(strategy) > 0

    # switch optimal 
    strategy.setOptimal(0)
    assert strategy.targetToken() == dai

    assert dai.balanceOf(strategy) == 0

    # wait for rewards
    chain.sleep(86400 * 7)  # 1 week
    chain.mine(1)

    strategy.harvest({"from": gov})

    dai.balanceOf(strategy) > 0

