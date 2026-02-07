{ config, pkgs, lib, ... }:

{
  imports = [ ./default.nix ];

  # K3s node configuration

  sops.secrets.k3s_token = {};
  
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  # Network configuration for K3s
  networking.extraHosts = "${config.cluster.masterIP} ${config.cluster.masterHostname}";
  
  # Firewall configuration for K3s node
  networking.firewall.allowedTCPPorts = [
    # Add any specific ports needed for worker nodes
  ];
  networking.firewall.allowedUDPPorts = [
    8472 # k3s, flannel: required if using multi-node for inter-node networking 
  ];

  # K3s service configuration for agent/node
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://${config.cluster.masterIP}:6443";
    tokenFile = config.sops.secrets.k3s_token.path;
    extraFlags = toString [
      # Add any specific flags for worker nodes
    ];
  };
}
