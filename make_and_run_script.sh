#!/bin/bash
set -euxo pipefail

make
./bin/svim
