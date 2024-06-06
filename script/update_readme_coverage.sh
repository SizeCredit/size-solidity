#!/usr/bin/env bash

set -eux

forge coverage > COVERAGE.txt
forge test > TEST.txt

TESTS=$(cat TEST.txt | grep -o 'test_\w\+' | sort | paste -sd' ' -)
SCENARIOS=$(node -e "
  const tests = process.argv[1].split(' ');
  const scenarios = {}
  for (const test of tests) {
    const feature = test.split('_')[1];
    scenarios[feature] = scenarios[feature] || 0;
    scenarios[feature]++;
  }
  console.log('\`\`\`markdown');
  console.table(scenarios);
  console.log('\`\`\`');
" "$TESTS")

BEGIN=$(grep -n BEGIN_COVERAGE README.md | cut -d : -f 1)
END=$(grep -n END_COVERAGE README.md | cut -d : -f 1)

PART_1=$(head -n $((BEGIN)) README.md)
PART_3=$(tail -n +$((END)) README.md)

COVERAGE_BEGIN=$(grep -n '\bFile\b' COVERAGE.txt | cut -d : -f 1)
COVERAGE=$(tail -n +$((COVERAGE_BEGIN)) COVERAGE.txt | grep -v 'test/' | grep -v 'script/' | grep -v '\bTotal\b')

echo "$PART_1" > README.md
echo "### FIles" >> README.md
echo "" >> README.md
echo "$COVERAGE" >> README.md
echo "" >> README.md
echo "### Tests per file" >> README.md
echo "" >> README.md
echo "$SCENARIOS" >> README.md
echo "$PART_3" >> README.md

rm COVERAGE.txt
rm TEST.txt