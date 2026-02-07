# NixOS Cluster Configuration

Declarative NixOS flake managing a 7-node bare-metal cluster with K3s orchestration, NVIDIA GPU passthrough, and encrypted secrets.

## Cluster overview

| Host   | IP           | Role        | Services                    |
| ------ | ------------ | ----------- | --------------------------- |
| flo    | 192.168.0.10 | K3s master  | K3s server, Pangolin tunnel |
| rob    | 192.168.0.11 | K3s worker  | K3s agent                   |
| bob    | 192.168.0.12 | K3s worker  | K3s agent                   |
| ping   | 192.168.0.13 | GPU compute | NVIDIA + CUDA               |
| oogway | 192.168.0.14 | GPU compute | NVIDIA + CUDA               |
| shifu  | 192.168.0.15 | GPU compute | NVIDIA + CUDA               |
| monkey | 192.168.0.16 | GPU compute | NVIDIA + CUDA               |

All nodes share: NixOS 24.11, NVIDIA drivers, Zsh + Starship, hardened SSH, fail2ban, AppArmor, sops-nix secrets.

## Quick start

```bash
# 1. Enter sudo
sudo -i

# 2. Launch the update script (set correct hostname before)
curl -sL https://raw.githubusercontent.com/DaVinciBot/ClusterConfig/refs/heads/main/update.sh | bash
```

## Adding a new host

1. Create `hosts/<name>/default.nix`:
   ```nix
   { config, pkgs, ... }:
   {
     imports = [ ../../modules/services/nvidia.nix ];  # pick your services
     networking.hostName = "<name>";
     networking.interfaces.eno1.ipv4.addresses = [{
       address = "192.168.0.xx";
       prefixLength = 24;
     }];
   }
   ```
2. Register it in `flake.nix`:
   ```nix
   <name> = mkHost "<name>" [];
   ```
3. Deploy the age key to the host, then `./update.sh -h <name>`.

## Development

```bash
nix develop        # dev shell with sops, age, ssh-to-age
nix fmt            # format all Nix files (nixpkgs-fmt)
nix flake check    # validate the full configuration
```

## Repository layout

```
flake.nix                         Flake inputs, mkHost helper, devShell, formatter
hosts/<name>/default.nix          Per-host: IP, hostname, service imports, mounts
modules/core/                     Base config applied to every host
  locale  networking  nix  packages  security  shell  system  users
modules/services/
  nvidia.nix                      NVIDIA drivers + CUDA + container toolkit
  docker.nix                      Docker daemon (opt-in)
  tunnel.nix                      Pangolin tunnel via newt
  k3s/{default,master,node}.nix   K3s cluster (shared options + roles)
secrets/secrets.yaml              age-encrypted secrets (sops)
update.sh                         Local pull-and-rebuild script
```