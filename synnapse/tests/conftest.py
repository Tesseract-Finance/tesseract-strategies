import pytest
from brownie import config
from brownie import Contract


@pytest.fixture
def gov(accounts):
    yield accounts.at("0xd131Ff7caF3a2EdD4B1741dd8fC2F9A92A13cD25", force=True)


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
    token_address = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063"  # this should be the address of the ERC-20 used by the strategy/vault (DAI)
    yield Contract(token_address)


@pytest.fixture
def amount(accounts, token, user):
    amount = 10_000 * 10 ** token.decimals()
    # In order to get some funds for the token you are about to use,
    # it impersonate an exchange address to use it's funds.
    reserve = accounts.at("0x4a35582a710e1f4b2030a3f826da20bfb6703c09", force=True)
    token.transfer(user, amount, {"from": reserve})
    yield amount


@pytest.fixture
def weth():
    token_address = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
    yield Contract(token_address)


@pytest.fixture
def weth_amout(user, weth):
    weth_amout = 10 ** weth.decimals()
    user.transfer(weth, weth_amout)
    yield weth_amout

@pytest.fixture
def curvePool():
    yield Contract("0x85fCD7Dd0a1e1A9FCD5FD886ED522dE8221C3EE5")

@pytest.fixture
def curveLpToken(curvePool):
    swapStorage = curvePool.swapStorage()
    yield swapStorage[-1]

@pytest.fixture
def maxSingleInvest(curvePool, token):
    tokenIndex = curvePool.getTokenIndex(token.address)
    tokenBalanceInPool = curvePool.getTokenBalance(tokenIndex)

    maxBps = 10_000
    maxPercentagePerSingleInvest = 500 #bps, 5%
    maxInvest = (tokenBalanceInPool * maxPercentagePerSingleInvest) / maxBps

    yield maxInvest

@pytest.fixture
def vault(pm, gov, rewards, guardian, management, token):
    Vault = pm(config["dependencies"][0]).Vault
    vault = guardian.deploy(Vault)
    vault.initialize(token, gov, rewards, f"t{token.symbol()}", f"t{token.symbol()}", guardian, management)
    vault.setDepositLimit(2 ** 256 - 1, {"from": gov})
    vault.setManagement(management, {"from": gov})
    vault.setManagementFee(0, {"from": gov})

    yield vault


@pytest.fixture
def lpVault(pm, gov, rewards, guardian, management, curveLpToken):
    Vault = pm(config["dependencies"][0]).Vault
    vault = guardian.deploy(Vault)

    vault.initialize(
        curveLpToken,
        gov,
        rewards,
        "lp Vault",
        "lp Vault",
        guardian,
        management
    )

    vault.setDepositLimit(2 ** 256 - 1, {"from": gov})
    vault.setManagement(management, {"from": gov})
    vault.setManagementFee(0, {"from": gov})

    yield vault


@pytest.fixture
def minTimePerInvest():
    yield 3600

@pytest.fixture
def slippageProtectionIn():
    yield 50

@pytest.fixture
def poolSize():
    yield 4

@pytest.fixture
def strategy(strategist, keeper, vault, lpVault, curveLpToken, curvePool, Strategy, gov, maxSingleInvest, minTimePerInvest, slippageProtectionIn, poolSize):
    strategistSender = { "from": strategist }

    strategy = Strategy.deploy(
        vault,
        maxSingleInvest,
        minTimePerInvest,
        slippageProtectionIn,
        curvePool.address,
        curveLpToken,
        lpVault.address,
        poolSize,
        "PSSP",
        strategistSender
    )
    strategy.setKeeper(keeper)
    vault.addStrategy(strategy, 10_000, 0, 2 ** 256 - 1, 1_000, {"from": gov})
    yield strategy


@pytest.fixture(scope="session")
def RELATIVE_APPROX():
    yield 1e1
