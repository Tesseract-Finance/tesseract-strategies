import pytest
from brownie import config, Wei, Contract, interface
from enum import Enum

class PoolTypes(Enum):
    ATRICRYPTO = 1
    AAVE = 2

@pytest.fixture(scope="module", params=[PoolTypes.ATRICRYPTO, PoolTypes.AAVE])
def poolType(request):
    yield request.param

# Snapshots the chain before each test and reverts after test completion.
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


@pytest.fixture(scope="module")
def whale(accounts, poolType):
    whaleAddress = ""
    if (poolType == PoolTypes.ATRICRYPTO):
        whaleAddress = "0x445fe580ef8d70ff569ab36e80c647af338db351"
    elif (poolType == PoolTypes.AAVE):
        whaleAddress = "0xb755b949c126c04e0348dd881a5cf55d424742b2"

    # Totally in it for the tech
    # Update this with a large holder of your want token (the largest EOA holder of LP)
    whale = accounts.at(whaleAddress, force=True)
    yield whale


# this is the amount of funds we have our whale deposit. adjust this as needed based on their wallet balance
@pytest.fixture(scope="module")
def amount(poolType):
    amount = 0
    if (poolType == PoolTypes.ATRICRYPTO):
        amount = 50e18
    elif (poolType == PoolTypes.AAVE):
        amount = 1e18 * 1_000_000

    yield amount


# this is the name we want to give our strategy
@pytest.fixture(scope="module")
def strategy_name():
    strategy_name = "CurveLpGaugeStrategy"
    yield strategy_name


# gauge for the curve pool
@pytest.fixture(scope="module")
def gauge(poolType):
    gauge = ""
    if (poolType == PoolTypes.ATRICRYPTO):
        gauge = "0x445FE580eF8d70FF569aB36e80c647af338db351"
    elif (poolType == PoolTypes.AAVE):
        gauge = "0x5B5CFE992AdAC0C9D48E05854B2d91C73a003858"

    yield interface.IGauge(gauge)


# curve deposit pool
@pytest.fixture(scope="module")
def pool(poolType):
    poolAddress = ""
    if (poolType == PoolTypes.ATRICRYPTO):
        poolAddress = "0x58e57cA18B7A47112b877E31929798Cd3D703b0f"
    elif (poolType == PoolTypes.AAVE):
        poolAddress = "0x7f90122BF0700F9E7e1F688fe926940E8839F353"
    yield poolAddress


# Define relevant tokens and contracts in this section
@pytest.fixture(scope="module")
def token(poolType):
    # this should be the address of the ERC-20 used by the strategy/vault
    token_address = ""
    if (poolType == PoolTypes.ATRICRYPTO):
        token_address = "0x1daB6560494B04473A0BE3E7D83CF3Fdf3a51828"
    elif (poolType == PoolTypes.AAVE):
        token_address = "0x1337BedC9D22ecbe766dF105c9623922A27963EC"
    yield Contract(token_address)


# Only worry about changing things above this line, unless you want to make changes to the vault or strategy.
# ----------------------------------------------------------------------- #


@pytest.fixture(scope="function")
def voter():  # set this to polygon gov for now
    yield Contract("0xe263A668bf09d0122Fa7f7fB3a8Df61fC8DA95De")


@pytest.fixture(scope="function")
def crv():
    yield Contract("0x249848BeCA43aC405b8102Ec90Dd5F22CA513c06")


@pytest.fixture(scope="module")
def other_vault_strategy():
    yield Contract("0x4d57fb3bE0Fee8850D9C7d9030e87166a4a76B09")


@pytest.fixture(scope="module")
def farmed():
    yield Contract("0x5947BB275c521040051D82396192181b413227A3")


@pytest.fixture(scope="module")
def healthCheck():
    yield Contract("0x6fD0f710f30d4dC72840aE4e263c22d3a9885D3B")


# zero address
@pytest.fixture(scope="module")
def zero_address():
    zero_address = "0x0000000000000000000000000000000000000000"
    yield zero_address


# Define any accounts in this section
# for live testing, governance is the strategist MS; we will update this before we endorse
# normal gov is ychad, 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52
@pytest.fixture(scope="module")
def gov(accounts):
    yield accounts.at("0xe263A668bf09d0122Fa7f7fB3a8Df61fC8DA95De", force=True)


@pytest.fixture(scope="module")
def strategist_ms(accounts):
    # set this to gov for polygon for now
    yield accounts.at("0xe263A668bf09d0122Fa7f7fB3a8Df61fC8DA95De", force=True)


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


@pytest.fixture(scope="module")
def strategist(accounts):
    yield accounts.at("0xBedf3Cf16ba1FcE6c3B751903Cf77E51d51E05b8", force=True)

@pytest.fixture(scope="module")
def strategyToDeploy(
    StrategyCurveaTricrypto,
    StrategyCurveAave,
    poolType
):
    if (poolType == PoolTypes.ATRICRYPTO):
        yield StrategyCurveaTricrypto
    elif (poolType == PoolTypes.AAVE):
        yield StrategyCurveAave

# use this if you need to deploy the vault
@pytest.fixture(scope="function")
def vault(pm, gov, rewards, guardian, management, token, chain):
    Vault = pm(config["dependencies"][0]).Vault
    vault = guardian.deploy(Vault)
    vault.initialize(token, gov, rewards, "", "", guardian)
    vault.setDepositLimit(2 ** 256 - 1, {"from": gov})
    vault.setManagement(management, {"from": gov})
    chain.sleep(1)
    yield vault

# replace the first value with the name of your strategy
@pytest.fixture(scope="function")
def strategy(
    strategyToDeploy,
    strategist,
    keeper,
    vault,
    gov,
    guardian,
    token,
    healthCheck,
    chain,
    pool,
    strategy_name,
    gauge,
    strategist_ms,
    voter
):
    # make sure to include all constructor parameters needed here
    strategy = strategist.deploy(
        strategyToDeploy,
        vault,
        gauge,
        strategy_name,
    )
    strategy.setKeeper(keeper, {"from": gov})
    # set our management fee to zero so it doesn't mess with our profit checking
    vault.setManagementFee(0, {"from": gov})
    # add our new strategy
    vault.addStrategy(strategy, 10_000, 0, 2 ** 256 - 1, 1_000, {"from": gov})
    strategy.setHealthCheck(healthCheck, {"from": gov})
    strategy.setDoHealthCheck(True, {"from": gov})
    strategy.setVoter(voter, {"from": gov})
    chain.sleep(1)
    strategy.harvest({"from": gov})
    chain.sleep(1)
    yield strategy
