{ config, pkgs, lib, ... }:

{
  imports = [ ./default.nix ];

  # K3s master configuration
  
  sops.secrets.k3s_token = {};

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  
  # add alias for k3s kubectl
  environment.shellAliases = {
    k = "k3s kubectl";
  };

  # Kubernetes packages
  environment.systemPackages = with pkgs; [
    kompose
    (wrapHelm kubernetes-helm {
        plugins = with pkgs.kubernetes-helmPlugins; [
          helm-secrets
          helm-diff
          helm-s3
          helm-git
        ];
      })
  ];

  # Network configuration for K3s
  networking.extraHosts = "${config.cluster.masterIP} ${config.cluster.masterHostname}";
  
  # Firewall configuration for K3s master
  networking.firewall.allowedTCPPorts = [
    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
    # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
    # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
  ];
  networking.firewall.allowedUDPPorts = [
    8472 # k3s, flannel: required if using multi-node for inter-node networking 
  ];

  # K3s service configuration
  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    tokenFile = config.sops.secrets.k3s_token.path;
    extraFlags = toString [
      # "--node-ip" config.cluster.masterIP
      # "--tls-san" config.cluster.masterHostname
      # "--advertise-address" config.cluster.masterIP
    ];
  };
}
