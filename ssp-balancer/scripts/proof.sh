#! /bin/bash
if [ ! -d bal-mining-scripts ]; then
    git clone -b feat/custom_proof_script https://github.com/Tesseract-Finance/bal-mining-scripts.git
    cd bal-mining-scripts
    git remote add upstream https://github.com/balancer-labs/bal-mining-scripts.git
    git fetch upstream
    git merge upstream/master feat/custom_proof_script
    echo "NETWORK=${1}" > .env
    npm install
else
    cd bal-mining-scripts
    git fetch upstream
    git merge upstream/master feat/custom_proof_script
fi



if [[ $1 = "polygon" ]]; then
    npx ts-node js/src/getProof.ts --recipient $2 --decimals $3 --balance $4 --outfile ../${1}_${5}_${2}.json
else
    npx ts-node js/src/getProof.ts --recipient $2 --decimals $3 --balance $4 --outfile ../${1}-tusd_${5}_${2}.json
fi
