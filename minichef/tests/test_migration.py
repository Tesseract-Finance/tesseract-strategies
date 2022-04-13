import pytest

def test_migration(
    chain,
    vault,
    strategy,
    gov,
    chef,
    router,
    pid,
    poolToken,
    amount,
    user
):

    #deposit to vault
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount
    # chain.sleep(1)
    # chain.mine(1)
    strategy.harvest({"from": gov})

    # tx = strategy.cloneStrategy(
    #     vault,
    #     chef,
    #     router,
    #     poolToken,
    #     pid
    # )
