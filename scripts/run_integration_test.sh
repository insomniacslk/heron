#!/bin/bash
#
# Script to locally run the functional integration test.
#

HTTP_SERVER="./bazel-bin/integration-test/src/python/http_server/http-server"
TEST_RUNNER="./bazel-bin/integration-test/src/python/test_runner/test-runner.pex"
INTEGRATION_TESTS="./bazel-genfiles/integration-test/src/java/integration-tests.jar"
CORE_PKG="file://`pwd`/bazel-bin/scripts/packages/heron-core.tar.gz"

set -e

function usage() {
  echo "Usage: $0 [platform]" >&2
  echo "Currently supported platforms are:" >&2
  echo "  darwin, ubuntu, and centos5" >&2
  exit 1
}

if [ $# -eq 1 ] && \
   [[ "$1" == "darwin" || "$1" == "ubuntu" || "$1" == "centos5" ]];
then
  PLATFORM="$1"
else
  usage
fi

# building tar packages
bazel run --config=${PLATFORM} -- scripts/packages:heron-client-install.sh --user
bazel build --config=${PLATFORM} {heron/...,scripts/packages:tarpkgs,integration-test/src/...}

# run the simple http server
${HTTP_SERVER} 8080 &
http_server_id=$!
trap "kill -9 $http_server_id" SIGINT SIGTERM EXIT

# run the integration tests
${TEST_RUNNER} \
  -hc heron -tj ${INTEGRATION_TESTS} \
  -rh localhost -rp 8080\
  -tp integration-test/src/java/com/twitter/heron/integration_test/topology/ \
  -cl local -rl heron-staging -ev devel -pi ${CORE_PKG}
