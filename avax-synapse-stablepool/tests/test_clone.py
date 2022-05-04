import math
import brownie
from brownie import Wei, accounts, Contract, config, chain


def test_cloning(
    gov,
    vault,
    user,
    strategist,
    keeper,
    rewards,
    minichef_vault,
    amount,
    strategy,
    strategy_name,
    usdc,
    Strategy
):
    with brownie.reverts():
        strategy.initialize(
            vault,
            strategist,
            rewards,
            keeper,
            minichef_vault,
            500_000e6,
            3600,
            500,
            strategy_name,
            {"from": gov}
        )
    
    # clone strategy

    tx = strategy.cloneSingleSideCurve(
            vault,
            strategist,
            rewards,
            keeper,
            minichef_vault,
            500_000e6,
            3600,
            500,
            strategy_name,
            {"from": gov}
    )

    newStrategy = Strategy.at(tx.return_value)

    with brownie.reverts():
        newStrategy.initialize(
            vault,
            strategist,
            rewards,
            keeper,
            minichef_vault,
            500_000e6,
            3600,
            500,
            strategy_name,
            {"from": gov}
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
    startingWhale = usdc.balanceOf(user)
    usdc.approve(vault, 2 ** 256 - 1, {"from": user})
    vault.deposit(amount, {"from": user})

    # harvest, store asset amount
    tx = newStrategy.harvest({"from": gov})
    assert usdc.balanceOf(newStrategy) == 0
    assert newStrategy.estimatedTotalAssets() > 0

    assert vault.pricePerShare() >= before_pps
    assert minichef_vault.balanceOf(newStrategy) > 0

