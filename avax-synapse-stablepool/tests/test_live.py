from itertools import count
from brownie import Wei, reverts, chain
import eth_abi
from brownie.convert import to_bytes
from useful_methods import genericStateOfStrat,genericStateOfVault
import random
import brownie


def test_opsss_live(amount, whale, gov, strategy, usdc, vault, user, poolToken, minichef_vault):
    usdc.approve(vault, amount, {"from": user})
    vault.deposit(amount, {"from": user})
    assert poolToken.balanceOf(strategy) == 0
    assert usdc.balanceOf(vault) > 0
    assert minichef_vault.balanceOf(strategy) == 0
    strategy.harvest({"from": gov})
    assert usdc.balanceOf(vault) == 0
    genericStateOfStrat(strategy, usdc, vault)

    genericStateOfVault(vault, usdc)

    chain.sleep(84600 * 10)
    chain.mine(1)
    strategy.setDoHealthCheck(False, {"from": gov})
    strategy.harvest({"from": gov})

    print("\nEstimated APR: ", "{:.2%}".format(((vault.totalAssets()-1000*1e18)*12)/(1000*1e18)))
    
   # vault.withdraw({"from": whale})
    print("\nWithdraw")
    genericStateOfStrat(strategy, usdc, vault)
    genericStateOfVault(vault, usdc)
  # print("Whale profit: ", (currency.balanceOf(whale) - whalebefore)/1e18)
    assert minichef_vault.balanceOf(strategy) > 0
    

