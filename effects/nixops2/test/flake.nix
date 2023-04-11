{
  description = "Deploy with NixOps and Hercules CI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # TODO change when merged
    # !!!: This isn't supported yet, so constructing the effect is done outside this flake.
    #      It is not representative of how you would wire it up normally.
    # hercules-ci-effects.url = "path:../..";
    hercules-ci-agent.url = "github:hercules-ci/hercules-ci-agent"; # TODO remove after hci release is in Nixpkgs
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, hercules-ci-agent, ... }:
    let
      inherit (nixpkgs) lib;

      perSystem = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
            };
            overlays = [
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
      };

      nixopsConfigurations = {
        default = {
          nixpkgs.legacyPackages = perSystem.pkgs;
          nixpkgs.lib = nixpkgs.lib;
          defaults = { config, ... }: { nixpkgs.pkgs = perSystem.pkgs.${config.nixpkgs.system}; };

          network.description = "hercules-ci/nixops-example";

          network.storage.hercules-ci.stateName = "runNixOps2-test.nixops";
          network.lock.hercules-ci.stateName = "runNixOps2-test.nixops";

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
              services.nginx.virtualHosts."${if config.networking.publicIPv4 == null then "ip-unknown" else config.networking.publicIPv4}".root = pkgs.myPkgs.my-web-root;
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
            inherit (ec2Defaults) region accessKeyId;
          };

          resources.ec2SecurityGroups.ec2SecurityGroups-web = { resources, ... }: {
            name = "nixops-example-web";
            description = "Allow HTTP/HTTPS access from anywhere";
            rules = [
              { fromPort = 80; toPort = 80; sourceIp = "0.0.0.0/0"; }
              { fromPort = 443; toPort = 443; sourceIp = "0.0.0.0/0"; }
            ];
            inherit (ec2Defaults) region accessKeyId;
          };
        };
      };
    };
}
