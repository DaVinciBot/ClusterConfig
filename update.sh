#!/usr/bin/env bash

set -euo pipefail

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Update NixOS configuration from the cluster config repository"
    echo ""
    echo "Options:"
    echo "  -h, --hostname HOSTNAME    Set the hostname for the NixOS rebuild (default: current hostname)"
    echo "  --help                     Show this help message and exit"
    echo ""
    echo "Examples:"
    echo "  $0                         # Use current hostname"
    echo "  $0 -h server01            # Use 'server01' as hostname"
    echo "  $0 --hostname k3s-master  # Use 'k3s-master' as hostname"
}

REPO_URL="https://github.com/davincibot/clusterconfig.git"
CLONE_DIR="/tmp/clusterconfig"
TARGET_DIR="/etc/nixos"
CURRENT_HOSTNAME=$(hostname)
SOPS_AGE_KEY="/var/lib/sops-nix/key.txt"
HW_CONFIG="${TARGET_DIR}/hardware-configuration.nix"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--hostname)
            if [[ -n "${2:-}" ]]; then
                CURRENT_HOSTNAME="$2"
                shift 2
            else
                echo "[ERROR] Hostname argument is required for -h/--hostname option"
                usage
                exit 1
            fi
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo "[INFO] Starting update script..."
echo "[INFO] Using hostname: $CURRENT_HOSTNAME"

# --- Pre-flight checks ---

# Ensure the sops age key is present (required for secret decryption)
if [[ ! -f "$SOPS_AGE_KEY" ]]; then
    echo "[WARN] sops age key not found at $SOPS_AGE_KEY"
    echo "        The age private key is required for sops-nix to decrypt secrets."
    echo ""
    echo "Paste your age private key below (starts with AGE-SECRET-KEY-1...)."
    echo "Press Enter then Ctrl-D when done:"
    echo ""

    KEY_CONTENT=$(cat)

    if [[ -z "$KEY_CONTENT" ]]; then
        echo "[ERROR] No key provided. Aborting."
        exit 1
    fi

    # Validate it looks like an age key
    if ! echo "$KEY_CONTENT" | grep -q "^AGE-SECRET-KEY-1"; then
        echo "[ERROR] Input does not look like a valid age private key (expected AGE-SECRET-KEY-1...)."
        exit 1
    fi

    sudo mkdir -p "$(dirname "$SOPS_AGE_KEY")"
    echo "$KEY_CONTENT" | sudo tee "$SOPS_AGE_KEY" > /dev/null
    sudo chmod 600 "$SOPS_AGE_KEY"
    echo "[INFO] Age key installed at $SOPS_AGE_KEY"
fi

# Generate hardware-configuration.nix if it doesn't exist yet
if [[ ! -f "$HW_CONFIG" ]]; then
    echo "[INFO] hardware-configuration.nix not found — generating it now..."
    sudo nixos-generate-config --show-hardware-config | sudo tee "$HW_CONFIG" > /dev/null
    echo "[INFO] Generated $HW_CONFIG"
else
    echo "[INFO] hardware-configuration.nix already exists, skipping generation."
fi

# --- Clone & copy ---

echo "[INFO] Removing old clone directory: $CLONE_DIR"
rm -rf "$CLONE_DIR"
echo "[INFO] Cloning repository from $REPO_URL to $CLONE_DIR"
git clone "$REPO_URL" "$CLONE_DIR"

# Backup hardware-configuration.nix before overwriting the target dir
if [[ -f "$HW_CONFIG" ]]; then
    cp "$HW_CONFIG" /tmp/hw-config-backup.nix
fi

# Copy repo files into /etc/nixos
echo "[INFO] Copying files from $CLONE_DIR to $TARGET_DIR"
sudo cp -rT "$CLONE_DIR" "$TARGET_DIR"

# Restore hardware-configuration.nix (the flake references it as ./hardware-configuration.nix)
if [[ -f /tmp/hw-config-backup.nix ]]; then
    sudo cp /tmp/hw-config-backup.nix "$HW_CONFIG"
    rm -f /tmp/hw-config-backup.nix
    echo "[INFO] Restored hardware-configuration.nix"
fi

# Flakes only see git-tracked files. hardware-configuration.nix is gitignored,
# so we must force-add it for the flake to find it during evaluation.
sudo git -C "$TARGET_DIR" add -f hardware-configuration.nix

# --- Rebuild ---

echo "[INFO] Rebuilding NixOS configuration for host: $CURRENT_HOSTNAME"
sudo nixos-rebuild switch --flake "${TARGET_DIR}#${CURRENT_HOSTNAME}"

echo "[INFO] Update script completed successfully."