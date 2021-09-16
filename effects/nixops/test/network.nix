let
  ec2Defaults = { region = "us-east-1"; accessKeyId = "foo-bar-test-profile"; };
in {
  network.description = "test-description";

  backend = { config, lib, resources, pkgs, ... }: {
    config = {
      deployment.targetEnv = "ec2";
      deployment.ec2 = {
        inherit (ec2Defaults) accessKeyId region;
        instanceType = "t3.small";
        keyPair = resources.ec2KeyPairs.nixops-keypair;
        securityGroups = [
          resources.ec2SecurityGroups.ec2SecurityGroups-web
          resources.ec2SecurityGroups.ec2SecurityGroups-ssh
        ];
      };
      # turns out publicIPv4 is not available on a fresh --dry-run either, so
      # we add one here. This shouldn't be necessary for real world deployments.
      networking.publicIPv4 = lib.mkForce "203.0.113.1";

      services.nginx.enable = true;
      services.nginx.virtualHosts."${config.networking.publicIPv4}".root = "${pkgs.nix.doc}/share/doc/nix/manual";
      networking.firewall.allowedTCPPorts = [80 443];
    };
  };

  resources.ec2KeyPairs.nixops-keypair = {
    inherit (ec2Defaults) accessKeyId region;
  };

  resources.ec2SecurityGroups.ec2SecurityGroups-ssh = { resources, ... }: {
    name = "nixops-example-ssh";
    description = "Allow SSH access from anywhere";
    rules = [
      { fromPort = 22; toPort = 22; sourceIp = "0.0.0.0/0"; }
    ];
    inherit (ec2Defaults) region tags accessKeyId;
  };

  resources.ec2SecurityGroups.ec2SecurityGroups-web = { resources, ... }: {
    name = "nixops-example-web";
    description = "Allow HTTP/HTTPS access from anywhere";
    rules = [
      { fromPort = 80; toPort = 80; sourceIp = "0.0.0.0/0"; }
      { fromPort = 443; toPort = 443; sourceIp = "0.0.0.0/0"; }
    ];
    inherit (ec2Defaults) region tags accessKeyId;
  };
}