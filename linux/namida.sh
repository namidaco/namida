#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LIBGL_ALWAYS_SOFTWARE=1
export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH
exec "$SCRIPT_DIR/namida_bin" "$@"