{ config, pkgs, lib, serverIP, secrets, ... }:

let
  kubeMasterIP = serverIP;  # Use the passed serverIP as master IP
  kubeMasterHostname = "api.kube";
in
{
  # K3s master configuration
  
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

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
  networking.extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";
  
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
    token = secrets.k3sToken;
    extraFlags = toString [
      # "--node-ip" kubeMasterIP
      # "--tls-san" kubeMasterHostname
      # "--advertise-address" kubeMasterIP
    ];
  };
}
