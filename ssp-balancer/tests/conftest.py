import pytest, requests
from brownie import config, chain
from brownie import Contract

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


@pytest.fixture
def gov(accounts):
    yield accounts.at("0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52", force=True)


@pytest.fixture
def user(accounts):
    yield accounts[0]


@pytest.fixture
def rewards(accounts):
    yield accounts[1]


@pytest.fixture
def guardian(accounts):
    yield accounts[2]


@pytest.fixture
def management(accounts):
    yield accounts[3]


@pytest.fixture
def strategist(accounts):
    yield accounts[4]


@pytest.fixture
def keeper(accounts):
    yield accounts[5]


@pytest.fixture
def token():
    # 0x6B175474E89094C44Da98b954EedeAC495271d0F DAI
    # 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 USDC
    # 0xdAC17F958D2ee523a2206206994597C13D831ec7 USDT
    # 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0 wSTETH
    # 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 WETH
    token_address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    yield Contract(token_address)


@pytest.fixture
def token2():
    # 0x6B175474E89094C44Da98b954EedeAC495271d0F DAI
    # 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 USDC
    # 0xdAC17F958D2ee523a2206206994597C13D831ec7 USDT
    # 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0 wSTETH
    # 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 WETH
    token_address = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    yield Contract(token_address)


@pytest.fixture
def token_whale(accounts):
    # 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643 DAI
    # 0x0A59649758aa4d66E25f08Dd01271e891fe52199 USDC
    # 0xA929022c9107643515F5c777cE9a910F0D1e490C USDT
    # 0xba12222222228d8ba445958a75a0704d566bf2c8 wSTETH
    # 0x2F0b23f53734252Bda2277357e97e1517d6B042A WETH
    return accounts.at("0x0A59649758aa4d66E25f08Dd01271e891fe52199", force=True)


@pytest.fixture
def amount(accounts, token, user, token_whale):
    amount = 10_000_000 * 10 ** token.decimals()
    # In order to get some funds for the token you are about to use,
    token.transfer(user, amount, {"from": token_whale})
    yield amount

@pytest.fixture
def token2_whale(accounts):
    # In order to get some funds for the token you are about to use,
    # 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643 DAI
    # 0x0A59649758aa4d66E25f08Dd01271e891fe52199 USDC
    # 0xA929022c9107643515F5c777cE9a910F0D1e490C USDT
    reserve = accounts.at("0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643", force=True)
    return reserve

@pytest.fixture
def usdc_whale(accounts):
    reserve = accounts.at("0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503", force=True)
    yield reserve

@pytest.fixture
def amount2(accounts, token2, user, token2_whale):
    amount = 1_000_000 * 10 ** token2.decimals()
    token2.transfer(user, amount, {"from": token2_whale})
    yield amount


@pytest.fixture
def weth():
    token_address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    yield Contract(token_address)


@pytest.fixture
def bal():
    token_address = "0xba100000625a3754423978a60c9317c58a424e3D"
    yield Contract(token_address)


@pytest.fixture
def bal_whale(accounts):
    yield accounts.at("0xBA12222222228d8Ba445958a75a0704d566BF2C8", force=True)


@pytest.fixture
def ldo():
    token_address = "0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32"
    yield Contract(token_address)


@pytest.fixture
def ldo_whale(accounts):
    yield accounts.at("0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c", force=True)


@pytest.fixture
def weth_amout(user, weth):
    weth_amout = 10 ** weth.decimals()
    user.transfer(weth, weth_amout)
    yield weth_amout


@pytest.fixture
def live_ssb_weth(Strategy):
    strat = "0xb8A245f9a066AD49fEAF15443E7704b83e2A9bF0"
    yield Strategy.at(strat)


@pytest.fixture
def live_dai_vault():
    vault = "0x1F8ad2cec4a2595Ff3cdA9e8a39C0b1BE1A02014"
    yield Contract(vault)


@pytest.fixture
def vault(pm, gov, rewards, guardian, management, token):
    Vault = pm(config["dependencies"][0]).Vault
    vault = guardian.deploy(Vault)
    vault.initialize(token, gov, rewards, "", "", guardian, management, {"from": gov})
    vault.setDepositLimit(2 ** 256 - 1, {"from": gov})
    vault.setManagement(management, {"from": gov})
    yield vault


@pytest.fixture
def vault2(pm, gov, rewards, guardian, management, token2):
    Vault = pm(config["dependencies"][0]).Vault
    vault = guardian.deploy(Vault)
    vault.initialize(token2, gov, rewards, "", "", guardian, management, {"from": gov})
    vault.setDepositLimit(2 ** 256 - 1, {"from": gov})
    vault.setManagement(management, {"from": gov})
    yield vault


@pytest.fixture
def balancer_vault():
    yield Contract("0xBA12222222228d8Ba445958a75a0704d566BF2C8")


@pytest.fixture
def pool():
    # 0x06Df3b2bbB68adc8B0e302443692037ED9f91b42 stable pool
    # 0x32296969Ef14EB0c6d29669C550D4a0449130230 metastable eth pool
    address = "0x06Df3b2bbB68adc8B0e302443692037ED9f91b42" # staBAL3
    yield Contract(address)


@pytest.fixture
def balWethPoolId():
    yield 0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014


@pytest.fixture
def wethTokenPoolId():
    id = 0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019  # weth-usdc
    yield id

@pytest.fixture
def wethToken2PoolId():
    id = 0x0b09dea16768f0799065c475be02919503cb2a3500020000000000000000001a  # weth-dai
    yield id

@pytest.fixture
def ldoWethPoolId():
    id = 0xbf96189eee9357a95c7719f4f5047f76bde804e5000200000000000000000087  # ldo-weth
    yield id


@pytest.fixture
def swapStepsBal(balWethPoolId, wethTokenPoolId, bal, weth, token):
    yield ([balWethPoolId, wethTokenPoolId], [bal, weth, token])

@pytest.fixture
def swapStepsLdo(ldoWethPoolId, wethTokenPoolId, ldo, weth, token):
    yield ([ldoWethPoolId, wethTokenPoolId], [ldo, weth, token])

@pytest.fixture
def swapStepsBal2(balWethPoolId, wethToken2PoolId, bal, weth, token2):
    yield ([balWethPoolId, wethToken2PoolId], [bal, weth, token2])

@pytest.fixture
def swapStepsLdo2(ldoWethPoolId, wethToken2PoolId, ldo, weth, token2):
    yield ([ldoWethPoolId, wethToken2PoolId], [ldo, weth, token2])


@pytest.fixture
def strategy(strategist, keeper, vault, Strategy, gov, balancer_vault, pool, bal, ldo, management, swapStepsBal,
             swapStepsLdo):
    strategy = strategist.deploy(Strategy, vault, balancer_vault, pool, 5, 5, 1_000_000, 2 * 60 * 60)
    strategy.setKeeper(keeper, {'from': gov})
    strategy.whitelistRewards(bal, swapStepsBal, {'from': gov})
    strategy.whitelistRewards(ldo, swapStepsLdo, {'from': gov})
    vault.addStrategy(strategy, 10_000, 0, 2 ** 256 - 1, 1_000, {"from": gov})
    chain.sleep(1)
    yield strategy


@pytest.fixture(scope="session")
def RELATIVE_APPROX():
    # making this more lenient bc of single sided deposits incurring slippage
    yield 1e-3
