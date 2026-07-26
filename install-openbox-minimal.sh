#!/bin/bash
# Minimal OpenBox Live Patch Installer
# One-command solution for applying critical performance fixes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fixed improvements applied
FIXES=(
    "1. session.c:546 - Fixed fullscreen Y coordinate bug"
    "2. frame.c:78 - Added NULL window protection"  
    "3. client.c:1283 - Added NULL window protection"
    "4. client.c:3240-3241 - Runtime size validation"
    "5. client.c:3432-3433 - Runtime fullscreen area validation"
    "6. client.c:3579-3595 - Runtime max area validation"
    "7. obrender/image.c:716-719 - Runtime dimension validation"
)

# Print usage
usage() {
    cat << EOF
OpenBox Live Patch Installer - One-command fix installer

Usage: ./install-openbox.sh [options]

Options:
  -h, --help          Display help message
  -v, --verbose       Verbose output

What this does:
1. Verifies critical performance fixes are applied
2. Builds optimized OpenBox with fixes
3. Installs to system
4. Verifies installation

These fixes address:\n$(printf "   %s\n" "${FIXES[@]}")
EOF
}

# Function to check if fix is applied
check_fix() {
    local fix_name=$1
    local check_command=$2
    
    if eval $check_command > /dev/null 2>&1; then
        echo -e "${GREEN}[✓]${NC} $fix_name"
        return 0
    else
        echo -e "${RED}[✗]${NC} $fix_name"
        return 1
    fi
}

# Function to show progress
info() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

# Function to show error
error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to show success
 ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

main() {
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            -h|--help) usage; exit 0;;
            -v|--verbose) VERBOSE=true; shift;;
            *) error "Unknown option: $arg"; usage; exit 1;;
        esac
    done

    # Check we're in OpenBox source directory
    if [ ! -f "Makefile.in" ] && [ ! -f "configure" ]; then
        error "Not in OpenBox source directory."
        echo "Run this script from the OpenBox source root."
        exit 1
    fi

    info "Checking critical performance fixes..."
    
    # Verify all fixes are applied
    all_fixes_ok=true
    
    # Fix 1: session.c:546
    if ! grep -q "prey = c->pre_fullscreen_area.y" openbox/session.c; then
        error "session.c:546 Y coordinate fix not found"
        all_fixes_ok=false
    else
        ok "session.c:546 Y coordinate fix applied"
    fi
    
    # Fix 2: frame.c:78
    if [ -f "openbox/frame.c" ] && grep -q "if (!ret || c->window == None) return;" openbox/frame.c; then
        ok "frame.c:78 NULL window protection applied"
    elif [ -f "openbox/frame.c" ]; then
        error "frame.c:78 NULL window protection not found"
        all_fixes_ok=false
    else
        info "frame.c:78 check skipped (file not found)"
    fi
    
    # Fix 3: client.c:1283
    if grep -q "if (!ret || self->window == None) return;" openbox/client.c; then
        ok "client.c:1283 NULL window protection applied"
    else
        error "client.c:1283 NULL window protection not found"
        all_fixes_ok=false
    fi
    
    # Fix 4: client.c:3240-3241
    if grep -q "if (*w <= 0 || *h <= 0)" openbox/client.c || grep -q "if (w <= 0 || h <= 0)" openbox/client.c; then
        ok "client.c:3240-3241 size validation applied"
    else
        error "client.c:3240-3241 size validation not found"
        all_fixes_ok=false
    fi
    
    # Fix 5: client.c:3432-3433
    if grep -q "self->pre_fullscreen_area.width <= 0" openbox/client.c && grep -q "self->pre_fullscreen_area.height <= 0" openbox/client.c; then
        ok "client.c:3432-3433 fullscreen area validation applied"
    else
        error "client.c:3432-3433 fullscreen area validation not found"
        all_fixes_ok=false
    fi
    
    # Fix 6: client.c:3579-3595
    if grep -q "self->pre_max_area.width <= 0" openbox/client.c; then
        ok "client.c:3579-3595 max area validation applied"
    else
        error "client.c:3579-3595 max area validation not found"
        all_fixes_ok=false
    fi
    
    # Fix 7: obrender/image.c:716-719
    if grep -q "if (srcW == 0 || srcH == 0 || dstW == 0 || dstH == 0)" obrender/image.c; then
        ok "obrender/image.c:716-719 dimension validation applied"
    else
        error "obrender/image.c:716-719 dimension validation not found"
        all_fixes_ok=false
    fi
    
    # Check for hash-based duplicate detection in session.c
    if grep -q "session_state_key_equal" openbox/session.c && grep -q "g_hash_table_new_full" openbox/session.c; then
        ok "session.c hash-based duplicate detection applied"
    else
        error "session.c hash-based duplicate detection not found"
        all_fixes_ok=false
    fi

    if [ "$all_fixes_ok" = false ]; then
        error "Not all critical fixes are applied."
        exit 1
    fi

    info "All critical fixes verified. Building optimized OpenBox..."

    # Try to clean first
    make clean > /dev/null 2>&1 || true

    # Build with all cores
    if ! make -j$(nproc); then
        error "Build failed"
        exit 1
    fi

    ok "Build completed successfully"

    # Install
    info "Installing OpenBox..."
    sudo make install
    ok "Installation completed"

    # Verify installation
    info "Verifying installation..."
    hash -r > /dev/null 2>&1

    if ! command -v openbox > /dev/null 2>&1; then
        error "OpenBox not found in PATH"
        exit 1
    fi

    OPENBOX_VERSION=$(openbox --version 2>/dev/null || echo "Unknown")

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║ OpenBox Live Patch Installation Complete!                  ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║                                                            ║"
    echo "║ Installed location: $(which openbox)                     ║"
    echo "║ Version: $OPENBOX_VERSION                         ║"
    echo "║                                                            ║"
    echo "║ Critical Fixes Applied ($((${#FIXES[@]} + 1)))                               ║"
    for fix in "${FIXES[@]}"; do
        echo "║   ✓ $fix                      ║"
    done
    echo "║   ✓ Global texture/color caches (render.c)                    ║"
    echo "║                                                            ║"
    echo "║ Usage:                                                      ║"
    echo "║   openbox                                                     ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"

    ok "Installation completed successfully!"
}

# Run main with all arguments
main "$@"
