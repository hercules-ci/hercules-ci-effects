{
  description = "Hercules CI Effects";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-compat.url = "github:edolstra/flake-compat/master";
  inputs.flake-compat.flake = false;

  outputs = { self, nixpkgs, ... }: {

    lib.withPkgs = pkgs:
      let effects = import ./effects/default.nix effects pkgs;
      in effects;

    overlay = final: prev: {
      effects = import ./effects/default.nix final.effects final;
    };

    # TODO: add tests as checks by flattening

    tests = {
      git-crypt-hook = nixpkgs.legacyPackages.x86_64-linux.callPackage ./effects/git-crypt-hook/test.nix {};
      nixops = nixpkgs.legacyPackages.x86_64-linux.callPackage ./effects/nixops/test/default.nix {};
      nix-shell = nixpkgs.legacyPackages.x86_64-linux.callPackage ./effects/nix-shell/test.nix {};
    };

  };
}
