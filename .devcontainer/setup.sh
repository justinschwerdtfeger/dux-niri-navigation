#!/usr/bin/env bash
set -euo pipefail

npm ci
python3 scripts/setup-qml-tooling.py --dms-source /opt/dms/quickshell
printf 'Development tools and DMS imports are ready. Run make check and make test-qml.\n'
