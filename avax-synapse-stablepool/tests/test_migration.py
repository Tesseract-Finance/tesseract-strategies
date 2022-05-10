import pytest
import math
from brownie import chain, Strategy

def test_migration(
    gov,
    usdc,
    vault,
    strategist,
    healthCheck,
    amount,
    strategy_name,
    Strategy,
    user,
    strategy,
    minichef_vault,
    swapPool,
    poolSize,
    maxSingleInvest,
    minTimePerInvest,
    slippageProtectionIn,
    minichef_strategy,
    minichef_keeper
):
    usdc.approve(vault, 2 ** 256 -1, {"from": user})
    vault.deposit(amount, {"from": user})
    chain.sleep(1)
    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.harvest({"from": gov})
    chain.sleep(1)

    # deploy new strategy
    new_strategy = strategist.deploy(
        Strategy,
        vault,
        poolSize,
        maxSingleInvest,
        minTimePerInvest,
        slippageProtectionIn,
        swapPool,
        minichef_vault,
        strategy_name
    )
    total_old = strategy.estimatedTotalAssets()

    # can we harvest an unactivated strategy? should be no
    # under our new method of using min and maxDelay, this no longer matters or works
    # tx = new_strategy.harvestTrigger(0, {"from": gov})
    # print("\nShould we harvest? Should be False.", tx)
    # assert tx == False

    # simulate 1 day of earnings
    chain.sleep(86400)
    chain.mine(1)

    vault.migrateStrategy(strategy, new_strategy, {"from": gov})

    new_strategy.setHealthCheck(healthCheck, {"from": gov})
    new_strategy.setDoHealthCheck(True, {"from": gov})

    updated_total_old = strategy.estimatedTotalAssets()
    assert updated_total_old == 0

    # harvest to get funds back in strategy
    chain.sleep(1)
    new_strategy.setDoHealthCheck(False, {"from": gov})
    new_strategy.harvest({"from": gov})
    new_strat_balance = new_strategy.estimatedTotalAssets()

    # confirm we made money, or at least that we have about the same
    assert new_strat_balance >= total_old or math.isclose(
        new_strat_balance, total_old, abs_tol=5
    )


    startingVault = vault.totalAssets()
    print("\nVault starting assets with new strategy: ", startingVault)

    # simulate one day of earnings

    minichef_strategy.harvest({"from": minichef_keeper})
    chain.sleep(3600 * 6)  # 6 hrs needed for profits to unlock
    chain.mine(1)

    strategy.harvest()

    # Test out our migrated strategy, confirm we're making a profit
    new_strategy.setDoHealthCheck(False, {"from": gov})
    new_strategy.harvest({"from": gov})
    vaultAssets_2 = vault.totalAssets()
    # confirm we made money, or at least that we have about the same
    assert vaultAssets_2 >= startingVault or math.isclose(
        vaultAssets_2, startingVault, abs_tol=5
    )
    print("\nAssets after 1 day harvest: ", vaultAssets_2)