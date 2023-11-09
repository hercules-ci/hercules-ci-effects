{ nixpkgsFlake, pkgs }:
let
  effects = import ../../default.nix effects pkgs;

  pkgsInsecure = import pkgs.path {
    system = pkgs.stdenv.hostPlatform.system;
    config = {
      # FIXME
      permittedInsecurePackages = [
        "python3.10-requests-2.29.0"
        "python3.10-cryptography-40.0.2"
        "python3.10-cryptography-40.0.1"
      ];
    };
  };

  inherit (effects) mkEffect nix-shell;

  # Flakes do not support file:../.. yet, so we can't depend on
  # hercules-ci-effects here. Hence the fake flake.
  fakeFlake = let
      ec2Defaults = { region = "us-east-1"; accessKeyId = "foo-bar-test-profile"; };
  in {
    outPath = pkgs.lib.cleanSource ./.;
    nixopsConfigurations = {
      default = {

        nixpkgs = nixpkgsFlake;
        defaults = { config, lib, ... }: {
          nixpkgs.pkgs = pkgs;


          # TODO fix nixops docs by migrating them to markdown
          documentation.enable = lib.mkForce false;
        };

        network.description = "hercules-ci/nixops-example";

        network.storage.hercules-ci.stateName = "nixops-default";
        network.lock.hercules-ci.stateName = "nixops-default";

        backend = { config, resources, pkgs, ... }: {
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

            services.nginx.enable = true;  
            services.nginx.virtualHosts."${config.networking.publicIPv4}".root = "${pkgs.nix.doc}/share/doc/nix/manual/";
            networking.firewall.allowedTCPPorts = [ 80 443 ];
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
      };
    };
  };

  deploy = effects.runNixOps2 {
    flake = fakeFlake;
    nixops = pkgsInsecure.nixopsUnstable; # FIXME insecure flag should not be needed
    nix = pkgs.nixUnstable;

    # Override dynamic options for CI
    prebuildOnlyNetworkFiles = [
      (pkgs.writeText "stub.nix" ''
        { defaults = { lib, ... }: { networking.publicIPv4 = lib.mkForce "0.0.0.0"; }; }
      '')
    ];
    # Needs nixopsUnstable update for improved exprs
    # prebuildOnlyModules = [
    #   ({ }: { })
    # ];
    preUserSetup = ''
      mkdir -p ~/.config/nix/
      echo experimental-features = nix-command flakes >>~/.config/nix/nix.conf
    '';
    action = "dry-run";
    makeAnException = "I know this can corrupt the state, until https://github.com/NixOS/nixops/issues/1499 is resolved.";
    userSetupScript = ''
      writeAWSSecret nixops-example nixops-example
    '';
    priorCheckScript = "";
    effectCheckScript = "";
    secretsMap.nixops-example = "nixops-example-aws";
  };
in
deploy
