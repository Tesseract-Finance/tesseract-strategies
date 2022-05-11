import pytest
from brownie import Wei, reverts, chain


def test_revoke_strategy_from_vault(
    strategy, usdc, user, poolToken, gov, amount, RELATIVE_APPROX, vault
):
    # Deposit to the vault and harvest
    usdc.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    chain.sleep(1)
    strategy.harvest()
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    # In order to pass this tests, you will need to implement prepareReturn.
    # TODO: uncomment the following lines.
    vault.revokeStrategy(strategy.address, {"from": gov})
    chain.sleep(1)
    strategy.harvest()
    assert pytest.approx(usdc.balanceOf(vault.address), rel=RELATIVE_APPROX) == amount


def test_revoke_strategy_from_strategy(
    strategy, usdc, user, poolToken, gov, amount, RELATIVE_APPROX, vault
):
    # Deposit to the vault and harvest
    usdc.approve(vault.address, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    chain.sleep(1)
    strategy.harvest()
    assert pytest.approx(strategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == amount

    strategy.setEmergencyExit()
    chain.sleep(1)
    strategy.harvest()
    assert pytest.approx(usdc.balanceOf(vault.address), rel=RELATIVE_APPROX) == amount