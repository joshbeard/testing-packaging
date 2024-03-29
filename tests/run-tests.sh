#!/bin/bash
set -e
CURRENT_DIR=$(cd $(dirname $0) && pwd)
source $CURRENT_DIR/common.sh

FAILED=0
FAILED_TESTS=""
PASSED_TESTS=""

tests=$(ls $CURRENT_DIR/test-*.sh)

if [ -n "$1" ]; then
    tests=$(ls $CURRENT_DIR/test-$1*.sh)
fi

if [ -z "$tests" ]; then
    echo "No tests found in $CURRENT_DIR"
    exit 1
fi

for test_script in $tests; do
    echo "==============================================================================="
    echo "▶ Running $(basename $test_script) for $EXPECTED_VERSION"
    echo "==============================================================================="
    if ! bash $test_script; then
        echo "${red}FAILED: $(basename $test_script)${reset}"
        FAILED=1
        FAILED_TESTS="$FAILED_TESTS $(basename $test_script)"
        continue
    fi

    echo "${green}PASSED: $(basename $test_script)${reset}"
    PASSED_TESTS="$PASSED_TESTS $(basename $test_script)"
done

echo
echo "==============================================================================="
if [ $FAILED -eq 1 ]; then
    echo "${red}Failed:$FAILED_TESTS${reset}"
    if [ -n "$PASSED_TESTS" ]; then
        echo "${green}Passed:$PASSED_TESTS${reset}"
    fi
    exit 1
else
    echo "${green}All tests passed!${reset}"
fi
