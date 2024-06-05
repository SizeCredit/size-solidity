#!/usr/bin/env bash

set -ux

j=$((0x10)); 
SOLIDITY_FILES=$(find src/libraries test/helpers/libraries -type f | sed 's/.*\///' | sed 's/\.sol//')

rm COMPILE_LIBRARIES.txt || true
rm DEPLOY_CONTRACTS.txt || true

while read i; do 
    echo "($i,$(printf "0x%x" $j))" >> COMPILE_LIBRARIES.txt
    echo "[$(printf "\"0x%x\"" $j), \"$i\"]" >> DEPLOY_CONTRACTS.txt
    j=$((j+1))
done <<< "$SOLIDITY_FILES"

COMPILE_LIBRARIES=$(cat COMPILE_LIBRARIES.txt | paste -sd, -)
DEPLOY_CONTRACTS=$(cat DEPLOY_CONTRACTS.txt | paste -sd, -)

echo $COMPILE_LIBRARIES
echo $DEPLOY_CONTRACTS

sed -i "s/cryticArgs.*/cryticArgs: [\"--compile-libraries=$COMPILE_LIBRARIES\",\"--foundry-compile-all\"]/" echidna.yaml
sed -i "s/\"args\".*/\"args\": [\"--compile-libraries=$COMPILE_LIBRARIES\",\"--foundry-compile-all\"]/" medusa.json
sed -i "s/deployContracts.*/deployContracts: [$DEPLOY_CONTRACTS]/g" echidna.yaml

# find src/libraries/ -type f -exec sed -i 's/\spublic\s/ internal /g' {} \;
# find src/libraries/ -type f -exec sed -i 's/\sexternal\s/ internal /g' {} \;
# find src/libraries/ -type f -exec sed -i 's/\scalldata\s/ memory /g' {} \;

rm COMPILE_LIBRARIES.txt || true
rm DEPLOY_CONTRACTS.txt || true