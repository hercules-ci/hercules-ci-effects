{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs.follows = "nixpkgs";
    hercules-ci-effects.url = "github:hercules-ci/hercules-ci-effects";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ self, flake-parts, hercules-ci-effects, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, ... }: {
      imports = [
        hercules-ci-effects.flakeModule
      ];
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
        packages.hello = pkgs.hello;

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            # the Hercules CLI
            pkgs.hci
          ];
        };
      };
      flake = {
        # `withSystem` puts you in the "scope" of the `perSystem` module.
        # If you need to decide the `system` per effect, move `withSystem`
        # to the individual attributes:
        #     effects = { branch, ... }: {
        #       deploy = withSystem ({ effects, pkgs, ... }: effects.mkEffect ......); }
        #     };
        effects = { branch, ... }: withSystem "x86_64-linux" (
          { config, effects, pkgs, inputs', ... }:
          {
            # or runNixOS, netlifyDeploy, etc
            # https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/mkeffect/
            deploy = effects.mkEffect {
              effectScript = ''
                ${config.packages.hello}
              '';
            };
          }
        );
      };
    });

}
