{ config, pkgs, lib, inputs, ... }:

let
  # RustFS package from the flake
  rustfsPackage = inputs.rustfs.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # RustFS cluster node hostnames => IPs
  # These must be sequential for the {1...N} expansion notation
  rustfsNodes = {
    "rustfs1" = "192.168.0.10"; # flo
    "rustfs2" = "192.168.0.11"; # rob
    "rustfs3" = "192.168.0.12"; # bob
  };

  # MNMD volume definitions (2 server pools)
  #   Pool 1 (SSD): data stored on root filesystem
  #   Pool 2 (HDD): data stored on dedicated HDD mount
  ssdPool = "http://rustfs{1...3}:9000/data/rustfs-ssd";
  hddPool = "http://rustfs{1...3}:9000/media/hdd1/rustfs-hdd";
in
{
  # ---------------------------------------------------------------------------
  # Sops secrets for RustFS credentials
  # ---------------------------------------------------------------------------
  sops.secrets."rustfs/access_key" = {};
  sops.secrets."rustfs/secret_key" = {};

  # Runtime-rendered environment file with secrets injected by sops-nix
  sops.templates."rustfs-env" = {
    content = ''
      RUSTFS_ACCESS_KEY=${config.sops.placeholder."rustfs/access_key"}
      RUSTFS_SECRET_KEY=${config.sops.placeholder."rustfs/secret_key"}
      RUSTFS_ADDRESS=:9000
      RUSTFS_CONSOLE_ENABLE=true
      RUSTFS_CONSOLE_ADDRESS=:9001
      RUST_LOG=error
      RUSTFS_OBS_LOG_DIRECTORY=/var/log/rustfs
    '';
  };

  # ---------------------------------------------------------------------------
  # Host alias resolution for RustFS cluster nodes
  # ---------------------------------------------------------------------------
  networking.extraHosts = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: ip: "${ip} ${name}") rustfsNodes
  );

  # ---------------------------------------------------------------------------
  # Firewall — open RustFS API + Console ports
  # ---------------------------------------------------------------------------
  networking.firewall.allowedTCPPorts = [
    9000 # RustFS S3 API
    9001 # RustFS management console
  ];

  # ---------------------------------------------------------------------------
  # Data & log directories
  # ---------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "d /data/rustfs-ssd 0750 root root -"
    "d /media/hdd1/rustfs-hdd 0750 root root -"
    "d /var/log/rustfs 0750 root root -"
  ];

  # ---------------------------------------------------------------------------
  # RustFS systemd service (MNMD — 3 nodes × 2 disks)
  # ---------------------------------------------------------------------------
  systemd.services.rustfs = {
    description = "RustFS Object Storage Server";
    documentation = [ "https://rustfs.com/docs/" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";

      # Pass each server pool as a separate positional argument
      ExecStart = "${rustfsPackage}/bin/rustfs ${ssdPool} ${hddPool}";

      EnvironmentFile = config.sops.templates."rustfs-env".path;

      # Resource limits (per RustFS MNMD recommendations)
      LimitNOFILE = 1048576;
      LimitNPROC = 32768;

      Restart = "always";
      RestartSec = "10s";

      # Hardening
      NoNewPrivileges = true;
      ProtectHome = true;
      PrivateTmp = true;
      ProtectSystem = "full";

      # Logging
      StandardOutput = "append:/var/log/rustfs/rustfs.log";
      StandardError = "append:/var/log/rustfs/rustfs-err.log";
    };
  };

  # Add the RustFS binary to system PATH for admin convenience
  environment.systemPackages = [ rustfsPackage ];
}
