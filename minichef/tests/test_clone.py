import brownie
from brownie import Wei, accounts, Contract, config

# test passes as of 21-06-26
def test_cloning(
    gov,
    poolToken,
    vault,
    strategist,
    whale,
    strategy,
    keeper,
    rewards,
    chain,
    Strategy,
    amount,
    pid,
    strategy_name,
):
    # Shouldn't be able to call initialize again
    with brownie.reverts():
        strategy.initialize(
            vault,
            strategist,
            rewards,
            keeper,
            pid,
            strategy_name,
            {"from": gov},
        )

    # Shouldn't be able use mismatched poolToken and pid
    wrong_pid = pid + 1
    with brownie.reverts():
        strategy.cloneStrategy(
            vault,
            strategist,
            rewards,
            keeper,
            wrong_pid,
            strategy_name,
            {"from": gov},
        )

    ## clone our strategy
    tx = strategy.cloneStrategy(
        vault,
        strategist,
        rewards,
        keeper,
        1,
        strategy_name,
        {"from": gov},
    )
    newStrategy = Strategy.at(tx.return_value)

    # Shouldn't be able to call initialize again
    with brownie.reverts():
        newStrategy.initialize(
            vault,
            strategist,
            rewards,
            keeper,
            pid,
            strategy_name,
            {"from": gov},
        )

    ## shouldn't be able to clone a clone
    with brownie.reverts():
        newStrategy.cloneStrategy(
            vault,
            strategist,
            rewards,
            keeper,
            pid,
            strategy_name,
            {"from": gov},
        )

    # revoke and send all funds back to vault
    vault.revokeStrategy(strategy, {"from": gov})
    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.harvest({"from": gov})

    # attach our new strategy and approve it on the proxy
    vault.addStrategy(newStrategy, 10_000, 0, 2 ** 256 - 1, 1_000, {"from": gov})

    assert vault.withdrawalQueue(1) == newStrategy
    assert vault.strategies(newStrategy)[2] == 10_000
    assert vault.withdrawalQueue(0) == strategy
    assert vault.strategies(strategy)[2] == 0

    ## deposit to the vault after approving; this is basically just our simple_harvest test
    before_pps = vault.pricePerShare()
    startingWhale = poolToken.balanceOf(whale)
    poolToken.approve(vault, 2 ** 256 - 1, {"from": whale})
    vault.deposit(amount, {"from": whale})

    # harvest, store asset amount
    tx = newStrategy.harvest({"from": gov})
    old_pool_token = vault.totalAssets()
    assert old_pool_token > 0
    assert poolToken.balanceOf(newStrategy) == 0
    assert newStrategy.estimatedTotalAssets() > 0
    print("\nStarting Assets: ", old_pool_token / (10 ** poolToken.decimals()))

    # simulate nine days of earnings to make sure we hit at least one epoch of rewards
    chain.sleep(86400)
    chain.mine(1)

    # harvest after a day, store new asset amount
    newStrategy.setDoHealthCheck(False, {"from": gov})
    newStrategy.harvest({"from": gov})
    new_pool_token = vault.totalAssets()
    # we can't use strategyEstimated Assets because the profits are sent to the vault
    assert new_pool_token >= old_pool_token
    print("\nAssets after 2 days: ", new_pool_token / (10 ** poolToken.decimals()))

    # Display estimated APR
    print(
        "\nEstimated APR: ",
        "{:.2%}".format(
            ((new_pool_token - old_pool_token) * (365))
            / (newStrategy.estimatedTotalAssets())
        ),
    )

    apr = ((new_pool_token - old_pool_token) * (365)) / (
        newStrategy.estimatedTotalAssets()
    )
    assert apr >= 0

    # simulate a day of waiting for share price to bump back up
    chain.sleep(86400)
    chain.mine(1)

    # withdraw and confirm we made money
    vault.withdraw({"from": whale})
    assert poolToken.balanceOf(whale) >= startingWhale
    assert vault.pricePerShare() >= before_pps