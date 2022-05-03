{
  description = "Hercules CI Effects";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: {

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
        nixops = pkgs.callPackage ./effects/nixops/test/default.nix {};
        nix-shell = pkgs.callPackage ./effects/nix-shell/test.nix {};
        nixops2 = pkgs.callPackage ./effects/nixops2/test/default.nix { nixpkgsFlake = nixpkgs; };
        cachix-deploy = pkgs.callPackage ./effects/cachix-deploy/test.nix {};
        mkEffect = pkgs.callPackage ./effects/effect/test.nix {};
        ssh = effects.callPackage ./effects/ssh/test.nix {};
      };

    herculesCI = {
      onPush.default = {
        outputs.effects = { inherit (self) tests; };
      };
    };

    devShells.x86_64-linux.default =
      let pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in
      pkgs.mkShell {
        nativeBuildInputs = [ pkgs.nixpkgs-fmt ];
      };

  };
}
