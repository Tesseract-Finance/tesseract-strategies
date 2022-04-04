import os
import argparse
import sys
import json
import requests
import subprocess
import glob

from pathlib import Path

parser = argparse.ArgumentParser()

parser.add_argument('--strategies', type=str, nargs= '+', required=True)

parser.add_argument('--week', type=int, required=True)

parser.add_argument('--distNetwork', type=str, required=True)

parser.add_argument('--token', type=str, required=True)

parser.add_argument('--offset', type=int, required=True)

parse = parser.parse_args()


def main():
    strategies = parse.strategies
    week = parse.week
    network = parse.distNetwork
    token = parse.token
    offset = parse.offset
    url = f'https://raw.githubusercontent.com/balancer-labs/bal-mining-scripts/master/reports/{week}/__polygon_0x9a71012b13ca4d3d0cdc72a177df3ef03b0e76a3.json'
    resp = requests.get(url)
    data = json.loads(resp.text)    
    result = []

    # condition network token
    if network == 'polygon':
        namespace = "balancer-claims-polygon"
        symbol = "BAL"
        file = Path(f'polygon_{week}.json')
        checked_file = f"{network}_{week}_{strategies}*.json"
    else:
        namespace = "balancer-claims-tusd-polygon"
        symbol = "TUSD"
        file = Path(f'polygon-tusd_{week}.json')
        checked_file = f"{network}_tusd_{week}_{strategies}*.json"
    # fetch bal mining for data
    file.touch(exist_ok=True)
    length = len(strategies)
    for i in range(length):
        if strategies[i] in data:
            subprocess.check_output(['./proof.sh', str(network) , str(strategies[i]), str(18), str(data[strategies[i]]), str(week)])
    
    # append data
    for f in glob.glob(checked_file):
        with open(f, "rb") as infile:
            data = json.load(infile)
            address = data[0]['address']
            claim_amount = data[0]['claim_amount']
            hex_proof = data[0]['hex_proof']
            result.append({
                "address": address,
                "claim_amount": claim_amount,
                "hex_proof": hex_proof
            })      
    results = json.dumps({
        "config": {
        "token": symbol,
        "reportsDirectory": "../reports/",
        "reportFilename": f"/__polygon_{token}.json",
        "jsonSnapshotFilename": "_current-polygon.json",
        "fleekNamespace": namespace,
        "offset": offset,
        "week": week
        },
        "tokens_data": result
    }, indent=4, sort_keys=True)
    
    # create the file and clean repo
    if network == "polygon": 
        with open(f"{network}_{week}.json", "w") as outfile:
            outfile.write(results)
        for fn in glob.glob(f"{network}_{week}_*.json"):
            os.remove(fn)
    else:
        with open(f"{network}-tusd_{week}.json", "w") as outfile:
            outfile.write(results)
        for fn in glob.glob(f"{network}-tusd_{week}_*.json"):
            os.remove(fn)
    # clean repo
if __name__ == '__main__':
    main()



