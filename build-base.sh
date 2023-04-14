#! /bin/bash
set -euo pipefail

docker build -f Dockerfile.base -t microservice-base .
./docker-run.sh make install-tools
