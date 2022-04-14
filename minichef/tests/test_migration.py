import pytest

def test_migration(
    chain,
    vault,
    strategy,
    Strategy,
    gov,
    chef,
    router,
    pid,
    poolToken,
    synapseToken,
    amount,
    user,
    keeper,
    strategist,
    rewards,
):

    #deposit to vault
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount
    chain.sleep(1)
    chain.mine(1)
    strategy.harvest({"from": gov})
    
    assert strategy.estimatedTotalAssets() == amount
    
    tx = strategy.cloneStrategy(
        vault,
        chef,
        poolToken,
        synapseToken,
        router,
        strategist,
        rewards,
        keeper,
        pid
    )
    new_strategy = Strategy.at(tx.return_value)
    vault.migrateStrategy(strategy, new_strategy, {"from": gov})

    new_strategy.harvest({"from": gov})

    assert new_strategy.estimatedTotalAssets() == amount
