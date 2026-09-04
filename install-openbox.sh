#!/bin/bash

# Openbox Patchwork installer
# Build, test, and install the Openbox Patchwork maintenance fork.
# Usage: ./install-openbox.sh [options]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
BUILD_DIR="$(pwd)"
INSTALL_PREFIX="/usr/local"
VERBOSE=false
SKIP_TESTS=false

# Print usage information
function print_usage() {
    cat << EOF
Openbox Patchwork Installer

Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -v, --verbose          Enable verbose output
    --skip-tests           Skip running tests
    --install-path PREFIX  Installation prefix (default: $INSTALL_PREFIX)
    --build-dir DIR        Build directory (default: $BUILD_DIR)
    --rebuild              Rebuild even if build directory exists
    --dry-run              Show commands without executing

This script will:
1. Bootstrap the Openbox source
2. Configure with default settings
3. Build and test the patch set
4. Install Openbox Patchwork
5. Refresh PATH and verify installation

The patch set includes:
- stale X11 client cleanup
- bounded property, icon, and image handling
- safer geometry and session restoration
- targeted parsing and socket hardening

EOF
}

# Log function for verbose mode
function log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

# Error function
function error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Warning function
function warning() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

# Success function
function success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

# Check if we're root
function check_root() {
    if [ "$(id -u)" -eq 0 ]; then
        error "This script should not be run as root. Use sudo for installation."
        exit 1
    fi
}

# Check for required commands
function check_requirements() {
    local missing_cmds=()

    for cmd in "make" "gcc" "pkg-config" "sh"; do
        if ! command -v $cmd &>/dev/null; then
            missing_cmds+=($cmd)
        fi
    done

    if [ ${#missing_cmds[@]} -gt 0 ]; then
        error "Missing required commands: ${missing_cmds[*]}"
        error "Please install build tools and try again."
        exit 1
    fi

    success "Build requirements checked"
}

# Function to run command with retry
function run_command() {
    local attempt=1
    local max_attempts=3
    local temp_file

    while [ $attempt -le $max_attempts ]; do
        log "Attempt $attempt/$max_attempts: $*"

        if [ "$DRY_RUN" = true ]; then
            echo "DRY RUN: Would run: $*"
            return 0
        fi

        if temp_file=$(mktemp); then
            if "$@" > "$temp_file" 2>&1; then
                log "Command executed successfully"
                rm -f "$temp_file"
                return 0
            else
                local output
                output=$(cat "$temp_file" 2>/dev/null || echo "Command failed")
                rm -f "$temp_file"

                if [ $attempt -eq $max_attempts ]; then
                    error "Command failed after $max_attempts attempts:"
                    error "$output"
                    return 1
                fi

                warning "Command failed (attempt $attempt/$max_attempts): $output"
                warning "Retrying in 2 seconds..."
                sleep 2
            fi
        else
            error "Failed to create temporary file"
            return 1
        fi

        attempt=$((attempt + 1))
    done

    return 1
}

# Bootstrap step
function bootstrap() {
    local bootstrap_script="$BUILD_DIR/bootstrap"

    if [ ! -x "$bootstrap_script" ]; then
        error "Bootstrap script not found at $bootstrap_script"
        error "This repository may not be a standard Openbox source tree."
        return 1
    fi

    success "Bootstrapping Openbox..."
    if run_command bash "$bootstrap_script"; then
        success "Bootstrap completed successfully"
        return 0
    else
        error "Bootstrap failed"
        return 1
    fi
}

# Configure step
function configure() {
    local configure_script="$BUILD_DIR/configure"
    local configure_options="--prefix=$INSTALL_PREFIX --enable-debug"

    if [ ! -x "$configure_script" ]; then
        error "Configure script not found at $configure_script"
        return 1
    fi

    success "Configuring Openbox with options: $configure_options"
    if run_command bash "$configure_script" $configure_options; then
        success "Configuration completed successfully"
        return 0
    else
        error "Configuration failed"
        return 1
    fi
}

# Build step
function build() {
    local make_options="-j$(nproc)"

    success "Building Openbox with parallel jobs: $make_options"
    if run_command make $make_options; then
        success "Build completed successfully"
        return 0
    else
        error "Build failed"
        return 1
    fi
}

function test_build() {
    if [ "$SKIP_TESTS" = true ]; then
        warning "Skipping tests at user request"
        return 0
    fi

    success "Running test suite..."
    if run_command make check; then
        success "Tests completed successfully"
        return 0
    else
        error "Tests failed; refusing to install"
        return 1
    fi
}

# Install step
function install() {
    local install_script="$BUILD_DIR/make install"

    success "Installing Openbox Patchwork to $INSTALL_PREFIX"
    log "This will require administrator privileges."

    # Use sudo with password prompt
    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN: Would run sudo make install"
        return 0
    fi

    # Check if sudo is available
    if ! command -v sudo &>/dev/null; then
        error "sudo is not available. Please install sudo or run this script as root."
        return 1
    fi

    # Try to run with sudo password prompt
    echo "You will need to enter your password for sudo installation."
    if sudo make install; then
        success "Installation completed successfully"
        return 0
    else
        error "Installation failed"
        return 1
    fi
}

# Refresh PATH and verify
function verify() {
    local installed="$INSTALL_PREFIX/bin/openbox"

    success "Verifying installation..."

    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN: Would refresh PATH and run openbox --version"
        return 0
    fi

    if [ -x "$installed" ]; then
        local version_output
        version_output=$("$installed" --version 2>&1)

        if echo "$version_output" | grep -q "Openbox"; then
            success "Openbox Patchwork installation verified:"
            echo "  Version: $(echo "$version_output" | head -1)"
            echo "  Installation location: $installed"
            return 0
        else
            warning "Installed binary has unexpected version output:"
            echo "$version_output"
            return 0
        fi
    else
        error "Openbox was not installed at $installed"
        return 1
    fi
}

# Cleanup build artifacts
function cleanup() {
    success "Cleaning build artifacts..."

    if run_command make clean; then
        success "Cleanup completed"
        return 0
    else
        warning "Cleanup failed, but this is not critical"
        return 0
    fi
}

# Summary function
function print_summary() {
    cat << EOF

Openbox Patchwork installation complete.

  Binary: $INSTALL_PREFIX/bin/openbox
  Build directory: $BUILD_DIR
  Install prefix: $INSTALL_PREFIX

Select the locally installed Openbox session at login, or replace the
current window manager explicitly after saving your work.

EOF
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --install-path)
            if [ $# -lt 2 ]; then
                error "--install-path requires an argument"
                exit 1
            fi
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --build-dir)
            if [ $# -lt 2 ]; then
                error "--build-dir requires an argument"
                exit 1
            fi
            BUILD_DIR="$2"
            shift 2
            ;;
        --rebuild)
            REBUILD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            error "Unknown option: $1"
            exit 1
            ;;
        *)
            error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Openbox Patchwork Installer                                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # Check environment
    check_root
    check_requirements

    if ! cd "$BUILD_DIR"; then
        error "Cannot enter build directory: $BUILD_DIR"
        exit 1
    fi
    BUILD_DIR=$(pwd)

    # Build steps
    if [ "$REBUILD" = true ] || [ ! -f "$BUILD_DIR/configure" ]; then
        cleanup
        bootstrap || exit 1
    else
        success "Build directory already exists, skipping bootstrap"
    fi

    configure || exit 1
    build || exit 1
    test_build || exit 1
    install || exit 1
    verify || exit 1

    print_summary

    echo "✓ All tasks completed successfully!"
}

# Run main function
main
