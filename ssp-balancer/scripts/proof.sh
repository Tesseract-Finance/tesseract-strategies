#! /bin/bash
git clone -b feat/custom_proof_script https://github.com/Tesseract-Finance/bal-mining-scripts.git
cd bal-mining-scripts
echo "NETWORK=${1}" > .env
source .env
npm install
npx ts-node js/src/getProof.ts --recipient $2 --decimals $3 --balance $4
