import pytest
from brownie import Contract, accounts
import test_operation
import util


# old_dai to fixed_dai
def test_live_dai_migration(
        chain,
        vault,
        amount,
        Strategy,
        strategist,
        gov,
        user,
        RELATIVE_APPROX,
        balancer_vault, bal_whale,
        pool, ldo, ldo_whale, management, bal
):
    old = Contract("0x9cfF0533972da48Ac05a00a375CC1a65e87Da7eC")
    token = Contract(old.want())
    assert Contract(old.want()).symbol() == "DAI"

    vault = Contract(old.vault())
    gov = accounts.at(vault.governance(), force=True)
    fromGov = {'from': gov}

    util.stateOfStrat("old strategy before migration", old, token)

    fixed_strategy = Contract("0x3B7c81daa0F7C897b3e09352E1Ca2fBE93Ac234D")
    vault.migrateStrategy(old, fixed_strategy, fromGov)
    util.stateOfStrat("old strategy after migration", old, token)
    util.stateOfStrat("new strategy after migration", fixed_strategy, token)

    total_debt = vault.strategies(fixed_strategy)["totalDebt"]
    assert fixed_strategy.estimatedTotalAssets() >= total_debt

    # exit everything out and see how much we get
    fixed_strategy.setEmergencyExit(fromGov)
    fixed_strategy.harvest(fromGov)

    util.stateOfStrat("debt ratio 0", fixed_strategy, token)

    # hopefully the gains from trading fees cancels out slippage
    print(f'net loss from exit: {vault.strategies(fixed_strategy)["totalLoss"]}')
    assert fixed_strategy.estimatedTotalAssets() == 0


# clone fixed_dai to fixed_usdc, migrate old_usdc to fixed_usdc
def test_clone_usdc_then_migration(
        chain,
        vault,
        amount,
        Strategy,
        strategist,
        gov,
        user,
        RELATIVE_APPROX,
        balancer_vault, bal_whale,
        pool, ldo, ldo_whale, management, bal, swapStepsBal
):
    old = Contract("0x7A32aA9a16A59CB335ffdEe3dC94024b7F8A9a47")
    token = Contract(old.want())

    assert Contract(old.want()).symbol() == "USDC"

    vault = Contract(old.vault())
    fixed_original = Contract("0x3B7c81daa0F7C897b3e09352E1Ca2fBE93Ac234D")
    gov = accounts.at(vault.governance(), force=True)
    fromGov = {'from': gov}
    fixed_strategy = Strategy.at(fixed_original.clone(
        old.vault(),
        old.strategist(),
        old.rewards(),
        old.keeper(),
        old.balancerVault(),
        old.bpt(),
        old.maxSlippageIn(),
        old.maxSlippageOut(),
        old.maxSingleDeposit(),
        old.minDepositPeriod(),
        fromGov
    ).return_value)

    fixed_strategy.whitelistRewards(bal, swapStepsBal, {'from': gov})

    vault.migrateStrategy(old, fixed_strategy, fromGov)
    util.stateOfStrat("old strategy after migration", old, token)
    util.stateOfStrat("new strategy after migration", fixed_strategy, token)

    total_debt = vault.strategies(fixed_strategy)["totalDebt"]
    assert fixed_strategy.estimatedTotalAssets() >= total_debt

    pps_before = vault.pricePerShare()
    # test profitable harvest from unsold bals from old
    fixed_strategy.harvest(fromGov)

    util.stateOfStrat("new strategy after harvest", fixed_strategy, token)

    # pps unlock
    chain.sleep(3600 * 6)
    chain.mine(1)

    pps_after = vault.pricePerShare()
    assert pps_after > pps_before
    assert vault.strategies(fixed_strategy)["totalLoss"] == 0


# clone fixed_dai to fixed_usdc, migrate old_usdc to fixed_usdc
def test_clone_usdt_migration_give_debt(
        chain,
        vault,
        amount,
        Strategy,
        strategist,
        gov,
        user,
        RELATIVE_APPROX,
        balancer_vault, bal_whale,
        pool, ldo, ldo_whale, management, bal
):
    old = Contract("0x3ef6Ec70D4D8fE69365C92086d470bb7D5fC92Eb")
    token = Contract(old.want())

    assert Contract(old.want()).symbol() == "USDT"
    vault = Contract(old.vault())
    fixed_original = Contract("0x3B7c81daa0F7C897b3e09352E1Ca2fBE93Ac234D")
    gov = accounts.at(vault.governance(), force=True)
    fromGov = {'from': gov}
    fixed_strategy = Strategy.at(fixed_original.clone(
        old.vault(),
        old.strategist(),
        old.rewards(),
        old.keeper(),
        old.balancerVault(),
        old.bpt(),
        old.maxSlippageIn(),
        old.maxSlippageOut(),
        old.maxSingleDeposit(),
        old.minDepositPeriod(),
        fromGov
    ).return_value)

    vault.migrateStrategy(old, fixed_strategy, fromGov)
    util.stateOfStrat("old strategy after migration", old, token)
    util.stateOfStrat("new strategy after migration", fixed_strategy, token)

    total_debt = vault.strategies(fixed_strategy)["totalDebt"]
    assert fixed_strategy.estimatedTotalAssets() >= total_debt

    vault.updateStrategyDebtRatio(fixed_strategy, 1000, fromGov)

    pps_before = vault.pricePerShare()
    # test profitable harvest from unsold bals from old
    fixed_strategy.harvest(fromGov)

    util.stateOfStrat("new strategy after harvest with 10% debtRatio", fixed_strategy, token)

    assert fixed_strategy.estimatedTotalAssets() >= vault.strategies(fixed_strategy)["totalDebt"]


# clone fixed_dai to fixed_wbtc, migrate old_wbtc to fixed_wbtc
def test_clone_wbtc_then_migration(
        chain,
        vault,
        amount,
        Strategy,
        strategist,
        gov,
        user,
        RELATIVE_APPROX,
        balancer_vault, bal_whale,
        weth, balWethPoolId,
        pool, ldo, ldo_whale, management, bal, swapStepsBal
):
    old = Contract("0x7c1612476D235c8054253c83B98f7Ca6f7F2E9D0")
    token = Contract(old.want())

    assert Contract(old.want()).symbol() == "WBTC"

    vault = Contract(old.vault())
    fixed_original = Contract("0x3B7c81daa0F7C897b3e09352E1Ca2fBE93Ac234D")
    gov = accounts.at(vault.governance(), force=True)
    fromGov = {'from': gov}
    fixed_strategy = Strategy.at(fixed_original.clone(
        old.vault(),
        old.strategist(),
        old.rewards(),
        old.keeper(),
        old.balancerVault(),
        old.bpt(),
        old.maxSlippageIn(),
        old.maxSlippageOut(),
        old.maxSingleDeposit(),
        old.minDepositPeriod(),
        fromGov
    ).return_value)

    fixed_strategy.whitelistRewards(bal, ([balWethPoolId,
                                           0xa6f548df93de924d73be7d25dc02554c6bd66db500020000000000000000000e],
                                          [bal, weth, fixed_strategy.want()]), {'from': gov})

    vault.migrateStrategy(old, fixed_strategy, fromGov)
    util.stateOfStrat("old strategy after migration", old, token)
    util.stateOfStrat("new strategy after migration", fixed_strategy, token)

    total_debt = vault.strategies(fixed_strategy)["totalDebt"]
    assert fixed_strategy.estimatedTotalAssets() >= total_debt

    pps_before = vault.pricePerShare()
    # test profitable harvest from unsold bals from old
    fixed_strategy.harvest(fromGov)

    util.stateOfStrat("new strategy after harvest", fixed_strategy, token)

    # pps unlock
    chain.sleep(3600 * 6)
    chain.mine(1)

    pps_after = vault.pricePerShare()
    assert pps_after > pps_before
    assert vault.strategies(fixed_strategy)["totalLoss"] == 0


# clone fixed_dai to fixed_weth, migrate old_weth to fixed_weth
def test_clone_weth_then_migration(
        chain,
        vault,
        amount,
        Strategy,
        strategist,
        gov,
        user,
        RELATIVE_APPROX,
        balancer_vault, bal_whale,
        weth, balWethPoolId,
        pool, ldo, ldo_whale, management, bal, swapStepsBal
):
    old = Contract("0xc31763c0c3025b9DF3Fb7Cb7f4AC041866F64F2E")
    token = Contract(old.want())

    assert Contract(old.want()).symbol() == "WETH"

    vault = Contract(old.vault())
    fixed_original = Contract("0x3B7c81daa0F7C897b3e09352E1Ca2fBE93Ac234D")
    gov = accounts.at(vault.governance(), force=True)
    fromGov = {'from': gov}
    fixed_strategy = Strategy.at(fixed_original.clone(
        old.vault(),
        old.strategist(),
        old.rewards(),
        old.keeper(),
        old.balancerVault(),
        old.bpt(),
        old.maxSlippageIn(),
        old.maxSlippageOut(),
        old.maxSingleDeposit(),
        old.minDepositPeriod(),
        fromGov
    ).return_value)

    fixed_strategy.whitelistRewards(bal, ([balWethPoolId,
                                           0xa6f548df93de924d73be7d25dc02554c6bd66db500020000000000000000000e],
                                          [bal, weth, fixed_strategy.want()]), {'from': gov})

    vault.migrateStrategy(old, fixed_strategy, fromGov)
    util.stateOfStrat("old strategy after migration", old, token)
    util.stateOfStrat("new strategy after migration", fixed_strategy, token)

    total_debt = vault.strategies(fixed_strategy)["totalDebt"]
    assert fixed_strategy.estimatedTotalAssets() >= total_debt

    current_debt_ratio = vault.strategies(fixed_strategy)["debtRatio"]
    # exit a % out to test accounting and basic operation
    fixed_strategy.setParams(10, 10, fixed_strategy.maxSingleDeposit(), fixed_strategy.minDepositPeriod(), fromGov)
    fixed_strategy.harvest(fromGov)

    util.stateOfStrat("same dr, returned some debtOutstanding", fixed_strategy, token)

    # nothing to assert here. Harvest went through and didn't revert. We'll have to be careful with amount to exit
