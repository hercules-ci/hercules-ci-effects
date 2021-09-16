{
  description = "Deploy with NixOps and Hercules CI";

  inputs = {
    nixpkgs.url = "github:hercules-ci/nixpkgs/init-nixops-hercules-ci"; # TODO change when merged
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    hercules-ci-effects.url = "path:${toString ../..}";
    hercules-ci-agent.url = "github:hercules-ci/hercules-ci-agent"; # TODO remove after hci release is in Nixpkgs
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-compat-ci, flake-utils, hercules-ci-agent, hercules-ci-effects, ... }:
    let
      inherit (nixpkgs) lib;

      perSystem = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
            };
            overlays = [
              hercules-ci-effects.overlay
              (final: prev: {
                hci = hercules-ci-agent.packages.${system}.hercules-ci-cli;
              })
              self.overlay
            ];
          };
        in
        {
          legacyPackages = pkgs.myPkgs;

          packages = flake-utils.lib.flattenTree pkgs.myPkgs;

          devShell = pkgs.mkShell {
            nativeBuildInputs = [
              pkgs.nixopsUnstable
              pkgs.hci
            ];
            # NixOps still needs this. e.g. https://github.com/NixOS/nixops-aws/issues/144
            NIX_PATH="nixpkgs=${nixpkgs}";
          };

          checks = { };

          inherit pkgs;
        }
      );

      ec2Defaults = {
        # NOTE: this option can be used to select a profile as well.
        accessKeyId = "nixops-example";
        region = "us-east-1";
        tags = {};
      };
    in
    lib.filterAttrs (k: v: k != "pkgs") perSystem // {
      overlay = final: prev: {
        myPkgs = {
          my-web-root = final.runCommand "my-web-root" {
            nativeBuildInputs = [ final.cowsay final.hello ];
          } ''
            mkdir $out
            {
              echo "<pre>"
              hello | cowsay
              echo "</pre>"
            } >$out/index.html
          '';
        };

        # TODO: move this into hercules-ci-effects
        effects = prev.effects // {
          runNixOps2 = prev.callPackage ./hercules-ci-effects-wip/run-nixops.nix {
            inherit (final.effects) mkEffect;
          };
        };
      };

      ciNix = { src }: 
        flake-compat-ci.lib.recurseIntoFlakeWith {
          flake = self;
          systems = ["x86_64-linux"];
        } // {
          deployments = lib.recurseIntoAttrs {
            production =
              perSystem.pkgs.x86_64-linux.effects.runIf (src.ref == "refs/heads/main") (
                perSystem.pkgs.x86_64-linux.effects.runNixOps2 {
                  flake = self;
                  nixops = perSystem.pkgs.x86_64-linux.nixopsUnstable;

                  # Override dynamic options for CI
                  prebuildOnlyNetworkFiles = [(perSystem.pkgs.x86_64-linux.writeText "stub.nix" ''
                    { defaults = { lib, ... }: { networking.publicIPv4 = lib.mkForce "0.0.0.0"; }; }
                  '')];
                  preUserSetup = ''
                    mkdir -p ~/.config/nix/
                    echo experimental-features = nix-command flakes >>~/.config/nix/nix.conf
                  '';
                  effectScript = ''
                    nixops deploy
                  '';
                  userSetupScript = ''
                    writeAWSSecret nixops-example nixops-example
                  '';
                  secretsMap.nixops-example = "nixops-example-aws";
                }
              );
          };
        };

      nixopsConfigurations = {
        default = {
          nixpkgs.legacyPackages = perSystem.pkgs;
          nixpkgs.lib = nixpkgs.lib;
          defaults = { config, ... }: { nixpkgs.pkgs = perSystem.pkgs.${config.nixpkgs.system}; };

          network.description = "hercules-ci/nixops-example";

          network.storage.hercules-ci.stateName = "nixops-default.json"; # FIXME rename
          network.lock.hercules-ci.stateName = "nixops-default.json";

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
              services.nginx.virtualHosts."${config.networking.publicIPv4}".root = pkgs.myPkgs.my-web-root;
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
        };
      };
    };
}
