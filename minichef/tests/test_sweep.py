import brownie

def test_sweep(
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
    user
):
    # deposit to the vault
    assert poolToken.balanceOf(user) == amount 
    poolToken.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(vault) == amount

    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.harvest({"from": gov})
    chain.sleep(1)
    strategy.sweep(synapseToken, {"from": gov})

    poolToken.transfer(strategy, amount, {"from": whale})
    assert poolToken == strategy.want()
    assert poolToken.balanceOf(strategy) > 0

    with brownie.reverts("!want"):
        strategy.sweep(poolToken, {"from": gov})

    with brownie.reverts("!shares"):
        strategy.sweep(vault.address, {"from": gov})