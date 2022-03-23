import urllib.request, json
from brownie import Contract, accounts, web3
import click
import json


def main():
    ssb_dai = Contract('0x9cfF0533972da48Ac05a00a375CC1a65e87Da7eC')
    ssb_usdt = Contract('0x3ef6Ec70D4D8fE69365C92086d470bb7D5fC92Eb')
    ssb_usdc = Contract('0x7A32aA9a16A59CB335ffdEe3dC94024b7F8A9a47')
    ssb_wbtc = Contract('0x7c1612476D235c8054253c83B98f7Ca6f7F2E9D0')
    ssb_weth = Contract('0xc31763c0c3025b9DF3Fb7Cb7f4AC041866F64F2E')
    sms = Contract('0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7')

    strats = [ssb_dai, ssb_usdt, ssb_usdc, ssb_wbtc, sms]

    bal_distributor = Contract("0xd2EB7Bd802A7CA68d9AcD209bEc4E664A9abDD7b")
    merkleOrchard = Contract("0xdAE7e32ADc5d490a43cCba1f0c736033F2b4eFca")
    bal = "0xba100000625a3754423978a60c9317c58a424e3D"

    nextId = merkleOrchard.getNextDistributionId(bal, bal_distributor)
    for strat in strats:
        for i in range(59, nextId):
            claimed = merkleOrchard.isClaimed(bal, bal_distributor, i, strat)
            print(f'{strat} id: {i} {claimed}')
