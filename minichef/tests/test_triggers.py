from itertools import chain
import brownie
import math

def test_trigger(
    gov,
    whale,
    strategy,
    amount,
    poolToken,
    vault,
    chain
): 
    startingWhale = poolToken.balanceOf(whale)
    poolToken.approve(vault, 2 ** 256 - 1, {"from": whale})
    vault.deposit(amount, {"from": whale})
    chain.sleep(1)
    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.harvest({"from": gov})
    chain.sleep(1)

    chain.sleep(3600)
    chain.mine(1)
    
    # harvest should trigger false; hasn't been long enough
    tx = strategy.harvestTrigger(0, {"from": gov})
    print("\nShould we harvest? Should be False.", tx)
    assert tx == False


    # simulate 10 days of earnings
    chain.sleep(86400 * 10)
    chain.mine(1)

    # harvest should trigger true
    tx = strategy.harvestTrigger(0, {"from": gov})
    print("\nShould we harvest? Should be true.", tx)
    assert tx == True

    # simulate 2 days of earnings
    chain.sleep(86400 * 10)
    chain.mine(1)

    # harvest should trigger true
    tx = strategy.harvestTrigger(0, {"from": gov})
    print("\nShould we harvest? Should be true.", tx)
    assert tx == True

    # withdraw and confirm we made money
    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.harvest({"from": gov})

    # allow share price to rise
    chain.sleep(43200)
    chain.mine(1)

    vault.withdraw({"from": whale})
    assert poolToken.balanceOf(whale) >= startingWhale


def test_less_usefull_triggers(
    gov,
    poolToken,
    vault,
    strategy,
    chain,
    amount,
    whale
):
    poolToken.approve(vault, amount, {"from": whale})
    vault.deposit(amount, {"from": whale})
    chain.sleep(1)

    strategy.setMinReportDelay(100, {"from": gov})
    tx = strategy.harvestTrigger(0, {"from": gov})
    print("\nShould we harvest? Should be False.", tx)
    assert tx == False

    chain.sleep(200)