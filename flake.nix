{
  description = "Hercules CI Effects";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.hercules-ci-agent.url = "hercules-ci-agent/on-schedule";

  outputs = { self, nixpkgs, hercules-ci-agent, ... }: {

    flakeModule = {
      imports = [
        ./flake-modules/module-argument.nix
        ./flake-modules/herculesCI-attribute.nix
        ./flake-modules/herculesCI-helpers.nix
        ./effects/flake-update/flake-module.nix
      ];
    };

    lib.withPkgs = pkgs:
      let effects = import ./effects/default.nix effects (pkgs // { hci = hercules-ci-agent.packages.x86_64-linux.hercules-ci-cli; });
      in effects;

    overlay = final: prev: {
      effects = import ./effects/default.nix final.effects final;
    };

    # TODO: add tests as checks by flattening
    tests =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        effects = self.lib.withPkgs pkgs;
      in {
        flake-update = effects.callPackage ./effects/flake-update/test.nix {};
        git-crypt-hook = pkgs.callPackage ./effects/git-crypt-hook/test.nix {};
        # pyjwt is marked insecure; skip
        # nixops = pkgs.callPackage ./effects/nixops/test/default.nix {};
        nix-shell = pkgs.callPackage ./effects/nix-shell/test.nix {};
        nixops2 = pkgs.callPackage ./effects/nixops2/test/default.nix { nixpkgsFlake = nixpkgs; };
        cachix-deploy = pkgs.callPackage ./effects/cachix-deploy/test.nix {};
        mkEffect = pkgs.callPackage ./effects/effect/test.nix {};
        ssh = effects.callPackage ./effects/ssh/test.nix {};
        nixos = effects.callPackage ./effects/nixos/test.nix {};
      };
    checks.x86_64-linux.evaluation-checks =
      (import ./flake-modules/derivationTree-type.nix { inherit (nixpkgs) lib; }).tests nixpkgs.legacyPackages.x86_64-linux.emptyFile;

    herculesCI = { rev, branch, ... }: {
      onPush.default = {
        outputs.effects = let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in {
          tests = self.tests // {
            netlifyDeploy = pkgs.callPackage ./effects/netlify/test/default.nix { inherit rev; };
          };
        };
      };
    };

    devShells.x86_64-linux.default =
      let pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in
      pkgs.mkShell {
        nativeBuildInputs = [ pkgs.nixpkgs-fmt pkgs.hci ];
      };

    templates = rec {
      default = flake-parts;
      flake-parts = {
        path = ./templates/flake-parts;
        description = ''
          A demonstration of how to integrate effects with https://flake.parts.
        '';
      };
    };

  };
}
