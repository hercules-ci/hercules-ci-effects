{
  description = "Hercules CI Effects";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, ... }: {

    flakeModule = ./flake-module.nix;

    lib.withPkgs = pkgs:
      let effects = import ./effects/default.nix effects pkgs;
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
        git-crypt-hook = pkgs.callPackage ./effects/git-crypt-hook/test.nix {};
        # pyjwt is marked insecure; skip
        # nixops = pkgs.callPackage ./effects/nixops/test/default.nix {};
        nix-shell = pkgs.callPackage ./effects/nix-shell/test.nix {};
        nixops2 = pkgs.callPackage ./effects/nixops2/test/default.nix { nixpkgsFlake = nixpkgs; };
        cachix-deploy = pkgs.callPackage ./effects/cachix-deploy/test.nix {};
        mkEffect = pkgs.callPackage ./effects/effect/test.nix {};
        mkGitBranch = effects.callPackage ./effects/mk-git-branch/test/default.nix {};
        ssh = effects.callPackage ./effects/ssh/test.nix {};
        nixos = effects.callPackage ./effects/nixos/test.nix {};
      };

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
