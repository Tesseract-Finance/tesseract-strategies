import util
import pytest
import brownie
import test_operation


def test_clone(accounts, Strategy, strategy, strategist, rewards, keeper, token2, user, vault, vault2, amount2,
               balancer_vault,
               pool, chain, gov,
               RELATIVE_APPROX,
               bal, bal_whale, ldo, weth, weth_amout,
               ldo_whale, swapStepsBal2, swapStepsLdo2, management):
    with brownie.reverts("Strategy already initialized"):
        strategy.initialize(vault, strategist, rewards, keeper, balancer_vault, pool, 10, 10, 100_000, 2 * 60 * 60)

    transaction = strategy.clone(vault2, strategist, rewards, keeper, balancer_vault, pool, 10, 10, 100_000,
                                 2 * 60 * 60)
    cloned_strategy = Strategy.at(transaction.return_value)

    with brownie.reverts("Strategy already initialized"):
        cloned_strategy.initialize(vault, strategist, rewards, keeper, balancer_vault, pool, 10, 10, 100_000,
                                   2 * 60 * 60, {'from': gov})
    cloned_strategy.setKeeper(keeper, {'from': gov})
    cloned_strategy.whitelistRewards(bal, swapStepsBal2, {'from': management})
    cloned_strategy.whitelistRewards(ldo, swapStepsLdo2, {'from': management})
    vault2.addStrategy(cloned_strategy, 10_000, 0, 2 ** 256 - 1, 1_000, {"from": gov})

    # test operations with clone strategy
    test_operation.test_profitable_harvest(
        chain, token2, vault2, cloned_strategy, user, strategist, amount2, RELATIVE_APPROX, bal, bal_whale, ldo,
        ldo_whale, management)
