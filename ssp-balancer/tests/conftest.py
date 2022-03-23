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
    # 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063 DAI
    # 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 USDC
    # 0xc2132D05D31c914a87C6611C10748AEb04B58e8F USDT
    # 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619 WETH
    token_address = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
    yield Contract(token_address)


@pytest.fixture
def token2():
    # 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063 DAI
    # 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 USDC
    # 0xc2132D05D31c914a87C6611C10748AEb04B58e8F USDT
    # 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619 WETH
    token_address = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063"
    yield Contract(token_address)


@pytest.fixture
def token_whale(accounts):
    # 0x1aa6b8a508a97792ef675ff7472461f89db5d3a0 DAI
    # 0x25fca2f41e4d086eeccd4a9fbc6334cd8a70963c USDC
    # 0xf6422b997c7f54d1c6a6e103bcb1499eea0a7046 USDT
    # 0xdc9232e2df177d7a12fdff6ecbab114e2231198d WETH
    return accounts.at("0x25fca2f41e4d086eeccd4a9fbc6334cd8a70963c", force=True)


@pytest.fixture
def amount(accounts, token, user, token_whale):
    amount = 5_000_000 * 10 ** token.decimals()
    # In order to get some funds for the token you are about to use,
    token.transfer(user, amount, {"from": token_whale})
    yield amount

@pytest.fixture
def token2_whale(accounts):
    # In order to get some funds for the token you are about to use,
    # 0x1aa6b8a508a97792ef675ff7472461f89db5d3a0 DAI
    # 0x25fca2f41e4d086eeccd4a9fbc6334cd8a70963c USDC
    # 0xf6422b997c7f54d1c6a6e103bcb1499eea0a7046 USDT
    # 0xdc9232e2df177d7a12fdff6ecbab114e2231198d WETH
    reserve = accounts.at("0x27f8d03b3a2196956ed754badc28d73be8830a6e", force=True)
    return reserve

@pytest.fixture
def usdc_whale(accounts):
    reserve = accounts.at("0x25fca2f41e4d086eeccd4a9fbc6334cd8a70963c", force=True)
    yield reserve

@pytest.fixture
def amount2(accounts, token2, user, token2_whale):
    amount = 1_000_000 * 10 ** token2.decimals()
    token2.transfer(user, amount, {"from": token2_whale})
    yield amount


@pytest.fixture
def weth():
    token_address = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
    yield Contract(token_address)


@pytest.fixture
def bal():
    token_address = "0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3"
    yield Contract(token_address)


@pytest.fixture
def bal_whale(accounts):
    yield accounts.at("0x36cc7b13029b5dee4034745fb4f24034f3f2ffc6", force=True)

@pytest.fixture
def weth_amout(user, weth):
    weth_amout = 10 ** weth.decimals()
    user.transfer(weth, weth_amout)
    yield weth_amout

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
    address = "0x0d34e5dd4d8f043557145598e4e2dc286b35fd4f" # staBAL3
    yield Contract(address)


@pytest.fixture
def balTokenPoolId():
    yield 0x0297e37f1873d2dab4487aa67cd56b58e2f27875000100000000000000000002

@pytest.fixture
def tokenToken2PoolId():
    yield 0x0d34e5dd4d8f043557145598e4e2dc286b35fd4f000000000000000000000068

@pytest.fixture
def swapStepsBal(balTokenPoolId, bal, token):
    yield ([balTokenPoolId], [bal, token])

@pytest.fixture
def swapStepsBal2(balTokenPoolId, tokenToken2PoolId, bal, token, token2):
    yield ([balTokenPoolId, tokenToken2PoolId], [bal, token, token2])

@pytest.fixture
def strategy(strategist, keeper, vault, Strategy, gov, balancer_vault, pool, bal, management, swapStepsBal):
    strategy = strategist.deploy(Strategy, vault, balancer_vault, pool, 5, 5, 1_000_000, 2 * 60 * 60)
    strategy.setKeeper(keeper, {'from': gov})
    strategy.whitelistRewards(bal, swapStepsBal, {'from': gov})
    vault.addStrategy(strategy, 10_000, 0, 2 ** 256 - 1, 1_000, {"from": gov})
    chain.sleep(1)
    yield strategy


@pytest.fixture(scope="session")
def RELATIVE_APPROX():
    # making this more lenient bc of single sided deposits incurring slippage
    yield 1e-3
