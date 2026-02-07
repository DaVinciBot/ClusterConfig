{ lib, ... }:

{
  # Shared K3s cluster variables
  # Import this from master.nix and node.nix to avoid duplication
  options.cluster = {
    masterIP = lib.mkOption {
      type = lib.types.str;
      default = "192.168.0.10";
      description = "IP address of the K3s master node";
    };
    masterHostname = lib.mkOption {
      type = lib.types.str;
      default = "api.kube";
      description = "Hostname for the K3s API server";
    };
  };
}
