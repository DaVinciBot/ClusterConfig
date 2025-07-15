{ config, pkgs, lib, masterIP, secrets, ... }:

let
  kubeMasterIP = masterIP;  # Use the passed masterIP parameter
  kubeMasterHostname = "api.kube";
in
{
  # K3s node configuration
  
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  # Network configuration for K3s
  networking.extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";
  
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
    serverAddr = "https://${kubeMasterIP}:6443";
    token = secrets.k3sToken;
    extraFlags = toString [
      # Add any specific flags for worker nodes
    ];
  };
}
