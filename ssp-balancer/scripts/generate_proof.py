import argparse
import subprocess
import sys
import json
import requests

from pathlib import Path
from subprocess import check_output

parser = argparse.ArgumentParser()

parser.add_argument('--strategies', type=str, nargs= '+', required=True)

parser.add_argument('--week', type=int, required=True)

parser.add_argument('--distNetwork', type=str, required=True)

# parser.add_argument('distNetwork', type=str)

parse = parser.parse_args()


def main():
    # TODO get the json corresponding the week
    # loop to the provide address and get the amount
    strategies = parse.strategies
    week = parse.week
    network = parse.distNetwork
    url = f'https://raw.githubusercontent.com/balancer-labs/bal-mining-scripts/master/reports/{week}/__polygon_0x9a71012b13ca4d3d0cdc72a177df3ef03b0e76a3.json'
    resp = requests.get(url)
    data = json.loads(resp.text)    

    
    if network == "polygon":
        file = Path(f'polygon_{week}.json')
    else:
        file = Path(f'polygon-tusd_{week}.json')
    file.touch(exist_ok=True)
    length = len(strategies)
    for i in range(length):
        if strategies[i] in data:
            pass
           
    
if __name__ == '__main__':
    main()



