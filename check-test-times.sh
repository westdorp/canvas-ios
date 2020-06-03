#!/bin/zsh

# set -euo pipefail

TEST=./scripts/run-ui-tests.sh
TIMEFMT='%E'
CSV="$BITRISE_DEPLOY_DIR/times.csv"
TARGETS=($(jq -r < TestPlans/NightlyTests.xctestplan '.testTargets[].target.name'))
exclude=(StudentUITests StudentE2ETests)

touch $CSV
echo "target,startdate,time" >> $CSV
echo -n "BUILD,$(date)," >> $CSV
3>&1 { { time $TEST --only-build >&3 2>&1 } 2>&1 | tr -d s >> $CSV }
for target in ${exclude}; do
    echo -n "$target,$(date)," >> $CSV
    3>&1 { { time $TEST --only-testing $target >&3 2>&1 } 2>&1 | tr -d s >> $CSV }
done

echo -n "iPad,$(date)," >> $CSV
3>&1 { {
         time SCHEME=IPadTests \
              DEVICE_NAME='iPad Air (3rd generation)' \
              $TEST --all >&3 2>&1
     } 2>&1 | tr -d s >> $CSV }
