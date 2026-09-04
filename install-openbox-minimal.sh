#!/bin/sh

# Compatibility entry point retained for users of the old script name.
# Openbox Patchwork now has one build, test, and installation path.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

echo "install-openbox-minimal.sh now uses the standard Patchwork installer."
exec "$script_dir/install-openbox.sh" "$@"
