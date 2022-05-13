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
        whaleAddress = "0x0d41a70bc444eed5566cb32fcf3da011f78d09b3"
    elif (poolType == PoolTypes.AAVE):
        whaleAddress = "0x92215849c439e1f8612b6646060b4e3e5ef822cc"

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
        gauge = "0xBb1B19495B8FE7C402427479B9aC14886cbbaaeE"
    elif (poolType == PoolTypes.AAVE):
        gauge = "0x20759F567BB3EcDB55c817c9a1d13076aB215EdC"

    yield interface.IGauge(gauge)


# curve deposit pool
@pytest.fixture(scope="module")
def pool(poolType):
    poolAddress = ""
    if (poolType == PoolTypes.ATRICRYPTO):
        poolAddress = "0x1d8b86e3D88cDb2d34688e87E72F388Cb541B7C8"
    elif (poolType == PoolTypes.AAVE):
        poolAddress = "0x445FE580eF8d70FF569aB36e80c647af338db351"
    yield poolAddress


# Define relevant tokens and contracts in this section
@pytest.fixture(scope="module")
def token(poolType):
    # this should be the address of the ERC-20 used by the strategy/vault
    token_address = ""
    if (poolType == PoolTypes.ATRICRYPTO):
        token_address = "0xdAD97F7713Ae9437fa9249920eC8507e5FbB23d3"
    elif (poolType == PoolTypes.AAVE):
        token_address = "0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171"
    yield Contract(token_address)


# Only worry about changing things above this line, unless you want to make changes to the vault or strategy.
# ----------------------------------------------------------------------- #


@pytest.fixture(scope="function")
def voter():  # set this to polygon gov for now
    yield Contract("0xd131Ff7caF3a2EdD4B1741dd8fC2F9A92A13cD25")


@pytest.fixture(scope="function")
def crv():
    yield Contract("0x172370d5Cd63279eFa6d502DAB29171933a610AF")


@pytest.fixture(scope="module")
def other_vault_strategy():
    yield Contract("0xb1A092293290E60B288B2B75D83a1a086392C037")


@pytest.fixture(scope="module")
def farmed():
    yield Contract("0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39")


@pytest.fixture(scope="module")
def healthCheck():
    yield Contract("0xf1e3dA291ae47FbBf625BB63D806Bf51f23A4aD2")


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
    yield accounts.at("0xd131Ff7caF3a2EdD4B1741dd8fC2F9A92A13cD25", force=True)


@pytest.fixture(scope="module")
def strategist_ms(accounts):
    # set this to gov for polygon for now
    yield accounts.at("0xd131Ff7caF3a2EdD4B1741dd8fC2F9A92A13cD25", force=True)


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
