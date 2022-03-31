import urllib.request, json
from brownie import Contract, accounts, web3
import click
import json
import os


def main():
    dev = accounts.load(click.prompt("Account", type=click.Choice(accounts.load())))
    merkleOrchard = Contract("0x0F3e0c4218b7b0108a3643cFe9D3ec0d4F57c54e")

    bal = "0x9a71012b13ca4d3d0cdc72a177df3ef03b0e76a3"
    tusd = "0x2e1AD108fF1D8C782fcBbB89AAd783aC49586756"

    bal_distributor = "0xd2EB7Bd802A7CA68d9AcD209bEc4E664A9abDD7b"
    tusd_distributor = "0xc38c5f97B34E175FFd35407fc91a937300E33860"

    rewards = [("polygon_", bal, bal_distributor, "BAL"), ("polygon-tusd_", tusd, tusd_distributor, "TUSD")]

    for reward in rewards:
        for root, dirs, files in os.walk(f'./scripts'):
            for name in files:
                if name.startswith(reward[0]):
                    fileName = os.path.join(root, name)
                    f = open(fileName, )
                    data = json.load(f)
                    config = data["config"]
                    tokens_data = data["tokens_data"]
                    distributionId = config["week"] - config["offset"]

                    print(f'Week: {config["week"]}; Token to claim: {config["token"]}')
                    for token_data in tokens_data:
                        name = ""
                        try:
                            name = Contract(token_data["address"]).name()
                        except:
                            name = token_data["address"]
                        print(f'claiming {name}')
                        claim = [(distributionId,
                                  int(token_data["claim_amount"]),
                                  reward[2],
                                  0,
                                  token_data["hex_proof"])]
                        claimed = merkleOrchard.isClaimed(reward[1], reward[2], distributionId, token_data["address"])
                        print(f"claimed: {claimed}")
                        if not claimed:
                            tx = merkleOrchard.claimDistributions(token_data["address"], claim, [reward[1]], {'from': dev})
                            print(f'{name} claimed {int(token_data["claim_amount"]) / 1e18} {reward[3]} ')
