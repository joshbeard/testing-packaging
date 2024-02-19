#!/bin/bash

# Run each of the test scripts in this directory.
# If any of them fail, exit with a non-zero status code.
CURRENT_DIR=$(dirname $0)
FAILED=0
FAILED_TESTS=""
PASSED_TESTS=""

export REPO_BASE="https://pkgs.home.jbeard.dev"
export EXPECTED_VERSION=$(git describe --tags --always --dirty)

green=`tput setaf 2`
red=`tput setaf 1`
reset=`tput sgr0`

for test_script in $CURRENT_DIR/test-*.sh; do
    echo "==============================================================================="
    echo "▶ Running $test_script"
    echo "==============================================================================="
    if ! bash $test_script; then
        echo "${red}FAILED: ${test_script}${reset}"
        FAILED=1
        FAILED_TESTS="$FAILED_TESTS $test_script"
        continue
    fi

    echo "${green}PASSED: ${test_script}${reset}"
    PASSED_TESTS="$PASSED_TESTS $test_script"
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
