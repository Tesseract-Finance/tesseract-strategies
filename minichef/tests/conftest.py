import pytest
from brownie import config, Contract, interface, chain

# Snapshots the chain before each test and reverts after test completion.
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

@pytest.fixture(scope="module")
def whale(accounts):
    whale = accounts.at("0x2283ABD09435C7213894d229fbA8f654924dB8A0", force=True)
    yield whale

@pytest.fixture(scope="module")
def strategy_name():
    strategy_name = "StrategySynapseRewards"
    yield strategy_name


@pytest.fixture(scope="module")
def pid():
    pid_minichef = 1
    yield pid_minichef

@pytest.fixture(scope="module")
def chef():
    chefAddress = Contract("0x3a01521F8E7F012eB37eAAf1cb9490a5d9e18249")
    yield chefAddress


@pytest.fixture(scope="module")
def healthCheck():
    yield Contract("0x6fD0f710f30d4dC72840aE4e263c22d3a9885D3B")


@pytest.fixture(scope="function")
def voter():  # set this to polygon gov for now
    yield Contract("0xd131Ff7caF3a2EdD4B1741dd8fC2F9A92A13cD25")


# zero address
@pytest.fixture(scope="module")
def zero_address():
    zero_address = "0x0000000000000000000000000000000000000000"
    yield zero_address

# this is the name we want to give our strategy
@pytest.fixture(scope="module")
def strategy_name():
    strategy_name = "SynapseStaker"
    yield strategy_name


# Define any accounts in this section
# for live testing, governance is the strategist MS; we will update this before we endorse
# normal gov is ychad, 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52
@pytest.fixture(scope="module")
def gov(accounts):
    yield accounts.at("0xd131Ff7caF3a2EdD4B1741dd8fC2F9A92A13cD25", force=True)


@pytest.fixture(scope="module")
def strategist_ms(accounts):
    # set this to gov for polygon for now
    yield accounts.at("0xd131Ff7caF3a2EdD4B1741dd8fC2F9A92A13cD25", force=True)


@pytest.fixture(scope="module")
def synapseToken():
    tokenAddress = Contract("0x1f1E7c893855525b303f99bDF5c3c05Be09ca251")
    yield tokenAddress


@pytest.fixture(scope="module")
def poolToken():
    tokenAddress = Contract("0xCA87BF3ec55372D9540437d7a86a7750B42C02f4")
    yield tokenAddress

@pytest.fixture(scope="module")
def keeper(accounts):
    yield accounts.at("0xBedf3Cf16ba1FcE6c3B751903Cf77E51d51E05b8", force=True)


@pytest.fixture(scope="module")
def rewards(accounts):
    yield accounts.at("0xBedf3Cf16ba1FcE6c3B751903Cf77E51d51E05b8", force=True)


@pytest.fixture(scope="module")
def guardian(accounts):
    yield accounts[2]


@pytest.fixture(scope="module")
def management(accounts):
    yield accounts[3]

# @pytest.fixture(scope="module")
# def strategist(accounts):
#     yield accounts.at("0xBedf3Cf16ba1FcE6c3B751903Cf77E51d51E05b8", force=True)

# sushiswap router router address
@pytest.fixture(scope="module")
def router():
    router_address = Contract("0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506")
    yield router_address

@pytest.fixture(scope="module")
def user(accounts):
    yield accounts[4]

@pytest.fixture(scope="module")
def amount(poolToken, whale, user):
    _amountTransfered = 1_000 * 10 ** poolToken.decimals()
    poolToken.transfer(user, _amountTransfered, {"from": whale})
    balanceUser = poolToken.balanceOf(user)
    yield balanceUser


@pytest.fixture
def strategist(accounts):
    yield accounts[5]



@pytest.fixture(scope="module")
def dai():
    daiAddress = Contract("0xd586E7F844cEa2F87f50152665BCbc2C279D8d70")
    yield daiAddress

@pytest.fixture(scope="module")
def usdc():
    usdcAddress = Contract("0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E")
    yield usdcAddress

@pytest.fixture(scope="module")
def usdt():
    usdtAddress = Contract("0xc7198437980c041c805A1EDcbA50c1Ce5db95118")
    yield usdtAddress


# use this if you need to deploy the vault
@pytest.fixture(scope="function")
def vault(pm, gov, rewards, guardian, management, poolToken, chain, usdt):
    Vault = pm(config["dependencies"][0]).Vault
    vault = guardian.deploy(Vault)
    vault.initialize(poolToken, gov, rewards, "", "", guardian)
    vault.setDepositLimit(2 ** 256 - 1, {"from": gov})
    vault.setManagement(management, {"from": gov})
    chain.sleep(1)
    yield vault

@pytest.fixture(scope="function")
def strategy(
    Strategy,
    keeper,
    strategy_name,
    vault,
    strategist,
    gov,
    pid,
    healthCheck,
):
    strategy = strategist.deploy(
        Strategy,
        vault,
        pid,
        strategy_name
    )
    strategy.setKeeper(keeper, {"from": gov})
    # set our management fee to zero so it doesn't mess with our profit checking
    vault.setManagementFee(0, {"from": gov})
    # add our new strategy
    vault.addStrategy(strategy, 10_000, 0, 2 ** 256 - 1, 1_000, {"from": gov})
    strategy.setHealthCheck(healthCheck, {"from": gov})
    strategy.setDoHealthCheck(True, {"from": gov})
    yield strategy