from brownie import Contract
from brownie import config
import math


def test_simple_harvest(
    gov,
    poolToken,
    vault,
    strategist,
    whale,
    strategy,
    chain,
    strategist_ms,
    amount,
    accounts,
    chef,
    synapseToken,
    pid,
    usdt,
    dai
):
    ## deposit to the vault after approving
    startingWhale = poolToken.balanceOf(whale)
    poolToken.approve(vault, 2 ** 256 - 1, {"from": whale})
    vault.deposit(amount, {"from": whale})
    newWhale = poolToken.balanceOf(whale)

    # harvest, store asset amount
    chain.sleep(1)
    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.harvest({"from": gov})
    # assert dai.balanceOf(strategy) == 0
    chain.sleep(1)
    old_assets = vault.totalAssets()
    assert old_assets > 0
    assert poolToken.balanceOf(strategy) == 0
    assert strategy.estimatedTotalAssets() > 0
    print("\nStarting vault total assets: ", old_assets / (10 ** poolToken.decimals()))

    # simulate 12 hours of earnings
    chain.sleep(43200 * 20)
    chain.mine(1)

    # check on our pending rewards
    pending = chef.pendingSynapse(pid, strategy, {"from": whale})
    print(
        "This is our pending reward after 10 days: $"
        + str(pending / (10 ** synapseToken.decimals()))
    )

    # harvest, store new asset amount. Turn off health check since we are only ones in this pool.
    chain.sleep(43200 * 2)
    strategy.setDoHealthCheck(False, {"from": gov})
    tx = strategy.harvest({"from": gov})
    chain.sleep(1)

    new_assets = vault.totalAssets()
    # confirm we made money, or at least that we have about the same
    assert new_assets >= old_assets
    print(
        "\nVault total assets after 1 harvest: ", new_assets / (10 ** poolToken.decimals())
    )

    # Display estimated APR
    print(
        "\nEstimated APR: ",
        "{:.2%}".format(
            ((new_assets - old_assets) * (365 * 2)) / (strategy.estimatedTotalAssets())
        ),
    )

    gain = poolToken.balanceOf(vault)
    assert gain > 0

    # withdraw and confirm we made money, or at least that we have about the same
    vault.withdraw({"from": whale})
    assert poolToken.balanceOf(whale) > startingWhale