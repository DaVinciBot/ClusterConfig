# ClusterConfig — Full Documentation

## Table of contents

1. [Architecture overview](#1-architecture-overview)
2. [Technical choices](#2-technical-choices)
3. [Prerequisites](#3-prerequisites)
4. [Initial setup — from zero to a running cluster](#4-initial-setup--from-zero-to-a-running-cluster)
5. [Secrets management](#5-secrets-management)
6. [Module reference](#6-module-reference)
7. [Deploying & updating](#7-deploying--updating)
8. [Adding or removing a host](#8-adding-or-removing-a-host)
9. [Development workflow](#9-development-workflow)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Architecture overview

```
  ┌──────────────────── 192.168.0.0/24 ────────────────────┐
  │                                                        │
  │  ┌─────────┐   ┌─────────┐   ┌─────────┐               │
  │  │  flo    │   │  rob    │   │  bob    │               │
  │  │ .10     │   │ .11     │   │ .12     │               │
  │  │ master  │◄──│ worker  │   │ worker  │               │
  │  │ +tunnel │   │         │   │         │               │
  │  └─────────┘   └─────────┘   └─────────┘               │
  │       ▲                                                │
  │       │ K3s API :6443                                  │
  │       │                                                │
  │  ┌────┴────┐   ┌─────────┐   ┌─────────┐   ┌────────┐  │
  │  │  ping   │   │ oogway  │   │ shifu   │   │ monkey │  │
  │  │ .13     │   │ .14     │   │ .15     │   │ .16    │  │
  │  │ GPU     │   │ GPU     │   │ GPU     │   │ GPU    │  │
  │  └─────────┘   └─────────┘   └─────────┘   └────────┘  │
  └────────────────────────────────────────────────────────┘
         │
    Pangolin tunnel ──► https://pangolin.davincibot.fr
```

- **flo** is the single K3s control-plane node and exposes the cluster externally via a Pangolin/newt tunnel.
- **rob** and **bob** are K3s agent (worker) nodes.
- **ping, oogway, shifu, monkey** are standalone GPU compute nodes with NVIDIA drivers and CUDA — not currently joined to K3s.
- All 7 nodes run NixOS 25.11, share the same base configuration, and decrypt secrets at activation time via sops-nix.

---

## 2. Prerequisites

| Requirement                  | Version / Notes                                                                       |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| NixOS installed on each host | 25.11 (stable)                                                                        |
| Nix with flakes enabled      | `nix-command` + `flakes` experimental features                                        |
| An age keypair               | Generated via `age-keygen`                                                            |
| Network connectivity         | All hosts on `192.168.0.0/24`, internet access for Nix downloads                      |
| NVIDIA GPU (per host)        | Proprietary driver; UEFI Secure Boot must be **off** or configured for module signing |

On your **admin workstation** (where you edit and push config), you need:
- `nix` (with flakes)
- `sops`
- `age`
- `ssh-to-age` (handy for converting SSH host keys)
- `git`

All of these are available via `nix develop` in this repo.

---

## 3. Initial setup — from zero to a running cluster

### 3.1 Install NixOS on each host

Use the standard NixOS installer (minimal ISO). During installation:
1. Partition and format disks.
2. Run `nixos-generate-config --root /mnt` — this creates `/mnt/etc/nixos/hardware-configuration.nix`.
3. Install NixOS with a basic config just enough to boot and SSH in.

The `update.sh` script will auto-generate `hardware-configuration.nix` if it's missing, but having it from the installer is cleaner.

### 3.2 Clone this repo

```bash
git clone https://github.com/davincibot/clusterconfig.git
cd clusterconfig
```

### 3.3 Generate the age encryption key

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

The output will show a public key starting with `age1...`. Copy it.

### 3.4 Configure `.sops.yaml`

Open `.sops.yaml` and replace the placeholder with your public key:

```yaml
keys:
  - &admin_key age1yourpublickeyhere...
creation_rules:
  - path_regex: secrets/secrets\.yaml$
    key_groups:
    - age:
      - *admin_key
```

If you have multiple admins, add multiple keys to the `age:` list.

### 3.5 Create the secrets file

```bash
nix develop            # enter the dev shell
sops secrets/secrets.yaml
```

This opens your `$EDITOR`. Enter the following YAML structure:

```yaml
# K3s cluster join token — generate with: openssl rand -base64 32
k3s_token: "your-random-token-here"

# Pangolin tunnel credentials
tunnel:
  id: "your-tunnel-id"
  secret: "your-tunnel-secret"
  endpoint: "https://pangolin.davincibot.fr"

# Password hashes — generate with: mkpasswd -m yescrypt
user_passwords:
  dvb: "$y$j9T$..."

# SSH public keys
ssh_keys:
  dvb: "ssh-ed25519 AAAA..."
  urbain: "ssh-rsa AAAA..."
```

Save and exit. sops encrypts the file automatically.

### 3.6 Deploy the age key to each host

Every host needs the **private** age key so sops-nix can decrypt at activation time:

```bash
# For each host:
ssh dvb@192.168.0.XX '
  sudo mkdir -p /var/lib/sops-nix
  sudo tee /var/lib/sops-nix/key.txt > /dev/null
  sudo chmod 600 /var/lib/sops-nix/key.txt
' < ~/.config/sops/age/keys.txt
```

### 3.7 Deploy the NixOS configuration

**Option A** — run directly on each host:

```bash
# Copy the repo to the host
scp -r . dvb@192.168.0.10:/home/dvb/clusterconfig

# SSH in and rebuild
ssh dvb@192.168.0.10
cd clusterconfig
sudo nixos-rebuild switch --flake .#flo
```

**Option B** — use the update script (pulls from GitHub):

```bash
# On the host:
./update.sh                # uses $(hostname) automatically
./update.sh -h flo         # explicit hostname override
```

The update script will:
1. Check for the sops age key.
2. Generate `hardware-configuration.nix` if missing.
3. Git clone the repo to `/tmp/clusterconfig`.
4. Copy it to `/etc/nixos`.
5. Run `nixos-rebuild switch --flake /etc/nixos#<hostname>`.

### 3.8 Verify

```bash
# On the master (flo):
k get nodes              # should list flo, rob, bob

# On any node:
systemctl status k3s
systemctl status sops-nix
neofetch                 # → fastfetch
nvidia-smi               # GPU visible
```

---

## 4. Secrets management

### How it works

```
 .sops.yaml ──► defines which age keys can encrypt/decrypt
                    │
 sops secrets/secrets.yaml ──► edits the YAML in $EDITOR,
                                encrypts on save
                    │
 NixOS activation (nixos-rebuild switch)
                    │
 sops-nix module reads secrets.yaml
   ├─ decrypts with /var/lib/sops-nix/key.txt
   └─ writes plaintext to /run/secrets/<path>
                    │
 NixOS services reference config.sops.secrets."<path>".path
   e.g. services.k3s.tokenFile = config.sops.secrets.k3s_token.path
```

### Secret paths used

| Sops key             | Consumed by        | NixOS option                         |
| -------------------- | ------------------ | ------------------------------------ |
| `k3s_token`          | K3s master + nodes | `services.k3s.tokenFile`             |
| `tunnel/id`          | tunnel.nix         | systemd `ExecStart`                  |
| `tunnel/secret`      | tunnel.nix         | systemd `ExecStart`                  |
| `tunnel/endpoint`    | tunnel.nix         | systemd `ExecStart`                  |
| `user_passwords/dvb` | users.nix          | `users.users.dvb.hashedPasswordFile` |
| `ssh_keys/dvb`       | users.nix          | `openssh.authorizedKeys.keyFiles`    |
| `ssh_keys/urbain`    | users.nix          | `openssh.authorizedKeys.keyFiles`    |

### Rotating secrets

```bash
# 1. Edit the secret
sops secrets/secrets.yaml

# 2. Rebuild affected hosts
sudo nixos-rebuild switch --flake .#flo
```

### Rotating the age key

```bash
# 1. Generate a new key
age-keygen -o new-key.txt

# 2. Update .sops.yaml with the new public key
# 3. Re-encrypt the secrets file
sops updatekeys secrets/secrets.yaml

# 4. Deploy the new private key to all hosts
# 5. Rebuild all hosts
```

---

## 5. Module reference

### `modules/core/` — applied to every host via `commonModules`

| File             | What it configures                                                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `default.nix`    | Imports all other core modules                                                                                                              |
| `locale.nix`     | Timezone `Europe/Paris`, locale `fr_FR.UTF-8`, AZERTY keymap                                                                                |
| `networking.nix` | NetworkManager, gateway `192.168.0.1`, DNS `8.8.8.8` / `8.8.4.4`                                                                            |
| `nix.nix`        | Enables flakes, weekly GC (delete >30 d), store deduplication, 2 GB download buffer                                                         |
| `packages.nix`   | Common CLI tools: git, python3, tmux, btop, fastfetch, eza, bat, ripgrep, fd, fzf, jq, etc.                                                 |
| `security.nix`   | Kernel hardening (sysctl), AppArmor, auditd, fail2ban (5 attempts / 1 h ban), sops config, SSH hardening (key-only, no root, no forwarding) |
| `shell.nix`      | Zsh with autosuggestions + syntax highlighting, Starship prompt                                                                             |
| `system.nix`     | systemd-boot, no suspend/hibernate, watchdog, SMART monitoring, `stateVersion = "25.11"`                                                    |
| `users.nix`      | User `dvb` (wheel, networkmanager), immutable users, password + SSH keys from sops                                                          |

### `modules/services/` — opt-in, imported per host

| File              | What it configures                                                                                               |
| ----------------- | ---------------------------------------------------------------------------------------------------------------- |
| `nvidia.nix`      | Proprietary NVIDIA driver, modesetting, OpenGL 32-bit, nvidia-container-toolkit, CUDA toolkit, Blender with CUDA |
| `docker.nix`      | Docker daemon, auto-prune, log rotation, custom data root `/home/dvb/docker`                                     |
| `tunnel.nix`      | Pangolin tunnel via `/root/newt` binary, reads credentials from sops, runs as oneshot systemd service            |
| `k3s/default.nix` | Declares `cluster.masterIP` and `cluster.masterHostname` options (shared between master/node)                    |
| `k3s/master.nix`  | K3s server role, `clusterInit = true`, opens port 6443 + 8472, installs Helm + plugins, kompose                  |
| `k3s/node.nix`    | K3s agent role, connects to `https://<masterIP>:6443`, opens port 8472                                           |

### `flake.nix` — top-level

| Output                           | Description                                                    |
| -------------------------------- | -------------------------------------------------------------- |
| `nixosConfigurations.*`          | One entry per host, built via `mkHost "<name>" [extraModules]` |
| `devShells.x86_64-linux.default` | Dev shell with sops, age, ssh-to-age, nixos-rebuild            |
| `formatter.x86_64-linux`         | `nixpkgs-fmt` for `nix fmt`                                    |

The `mkHost` helper applies `commonModules` (sops-nix, `modules/core`, overlays, hardware-configuration) plus the host-specific directory and any extra modules.

The unstable overlay is available as `pkgs.unstable.*` on all hosts.

---

## 7. Deploying & updating

### Manual rebuild

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

### Using `update.sh`

```bash
./update.sh                    # auto-detects hostname
./update.sh -h flo             # explicit hostname
./update.sh --help             # usage info
```

The script:
1. Verifies the sops age key exists at `/var/lib/sops-nix/key.txt`.
2. Generates `/etc/nixos/hardware-configuration.nix` if missing (via `nixos-generate-config`).
3. Clones the repo from GitHub to `/tmp/clusterconfig`.
4. Copies it over `/etc/nixos`.
5. Runs `nixos-rebuild switch`.

### Updating flake inputs

```bash
nix flake update                    # update all inputs
nix flake update nixpkgs            # update just nixpkgs
nix flake update sops-nix           # update just sops-nix
```

After updating, rebuild and test on one host before rolling out to all.

### Rolling back

```bash
# List generations
sudo nix-env --list-generations -p /nix/var/nix/profiles/system

# Switch to a previous generation
sudo nixos-rebuild switch --rollback

# Or select a previous entry in the GRUB boot menu
```

---

## 8. Adding or removing a host

### Adding a host

1. **Create the host directory**:

   ```bash
   mkdir -p hosts/newhost
   ```

2. **Write `hosts/newhost/default.nix`**:

   ```nix
   { config, pkgs, ... }:
   {
     imports = [
       ../../modules/services/nvidia.nix     # if it has a GPU
       # ../../modules/services/k3s/node.nix # if joining the K3s cluster
     ];

     networking.hostName = "newhost";
     networking.interfaces.eno1.ipv4.addresses = [{
       address = "192.168.0.XX";
       prefixLength = 24;
     }];

     # Optional: additional filesystem mounts
     fileSystems."/media/hdd1" = {
       device = "/dev/disk/by-uuid/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
       fsType = "ext4";
       options = [ "defaults" "nofail" "x-systemd.automount" "x-systemd.device-timeout=10" ];
     };
   }
   ```

3. **Register in `flake.nix`** — add one line:

   ```nix
   newhost = mkHost "newhost" [];
   ```

4. **Deploy the age key** to the new host (see §4.6).

5. **Deploy**:

   ```bash
   ./update.sh -h newhost
   ```

### Removing a host

1. Delete `hosts/<name>/`.
2. Remove the line from `nixosConfigurations` in `flake.nix`.
3. Commit.

---

## 9. Development workflow

```bash
# Enter the dev shell (sops, age, ssh-to-age, nixos-rebuild)
nix develop

# Format all Nix files
nix fmt

# Validate the full configuration (catches type errors, missing options, etc.)
nix flake check

# Build a host without deploying (dry run)
nix build .#nixosConfigurations.flo.config.system.build.toplevel

# Edit secrets
sops secrets/secrets.yaml
```

### Code style

- All Nix files are formatted with `nixpkgs-fmt` (enforced via `nix fmt`).
- One module per concern (locale, networking, security, ...).
- Host files are minimal: just hostname, IP, imports, and mounts.
- Shared values (e.g. K3s master IP) live in NixOS options, never duplicated.

---

## 10. Troubleshooting

### `sops-nix` fails during activation

```
error: secret not found: /run/secrets/k3s_token
```

- Verify the age key is present: `ls -la /var/lib/sops-nix/key.txt`
- Verify the key can decrypt: `SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops -d secrets/secrets.yaml`
- Verify the secret name matches what the module expects (check `sops.secrets.*` declarations).

### `hardware-configuration.nix` not found

The flake references `/etc/nixos/hardware-configuration.nix`. If it doesn't exist:

```bash
sudo nixos-generate-config --show-hardware-config | sudo tee /etc/nixos/hardware-configuration.nix
```

The `update.sh` script does this automatically.

### K3s nodes don't join the cluster

1. Check the token matches on master and agent: both read from `sops.secrets.k3s_token`.
2. Check network connectivity: `curl -k https://192.168.0.10:6443` from the agent.
3. Check firewall: TCP 6443 and UDP 8472 must be open on the master.
4. Check logs: `journalctl -u k3s -f`

### NVIDIA driver issues

```bash
nvidia-smi                 # should list the GPU(s)
journalctl -b | grep nvidia # check for driver errors
```

- If Secure Boot is enabled, the unsigned NVIDIA module won't load. Disable Secure Boot in BIOS.
- If using a very old GPU (pre-Kepler), you may need `hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_XXX`.

### Tunnel not starting

```bash
systemctl status launch
journalctl -u launch -f
```

- The `newt` binary must exist at `/root/newt` (it is not managed by Nix).
- Check that the sops secrets `tunnel/id`, `tunnel/secret`, `tunnel/endpoint` are present.
