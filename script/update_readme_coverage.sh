#!/usr/bin/env bash

set -eu

forge coverage --ir-minimum > COVERAGE.txt

BEGIN=$(grep -n BEGIN_COVERAGE README.md | cut -d : -f 1)
END=$(grep -n END_COVERAGE README.md | cut -d : -f 1)

PART_1=$(head -n $((BEGIN)) README.md)
PART_3=$(tail -n +$((END)) README.md)

echo "$PART_1" > README.md
cat COVERAGE.txt | grep '\|' | grep -v 'test/' | grep -v '\bTotal\b' >> README.md
echo "$PART_3" >> README.md

rm COVERAGE.txt