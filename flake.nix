{
  description = "Hercules CI Effects";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # TODO remove when nixpkgs#138584 lands
  inputs.nixpkgs-nixops.url = "github:NixOS/nixpkgs/8d8a28b47b7c41aeb4ad01a2bd8b7d26986c3512";
  inputs.flake-compat.url = "github:edolstra/flake-compat/master";
  inputs.flake-compat.flake = false;

  outputs = { self, nixpkgs, nixpkgs-nixops, ... }: {

    lib.withPkgs = pkgs:
      let effects = import ./effects/default.nix effects pkgs;
      in effects;

    overlay = final: prev: {
      effects = import ./effects/default.nix final.effects final;
    };

    # TODO: add tests as checks by flattening

    tests = {
      git-crypt-hook = nixpkgs.legacyPackages.x86_64-linux.callPackage ./effects/git-crypt-hook/test.nix {};
      nixops = nixpkgs-nixops.legacyPackages.x86_64-linux.callPackage ./effects/nixops/test/default.nix {};
      nix-shell = nixpkgs.legacyPackages.x86_64-linux.callPackage ./effects/nix-shell/test.nix {};
      nixops2 = nixpkgs.legacyPackages.x86_64-linux.callPackage ./effects/nixops2/test/default.nix { nixpkgsFlake = nixpkgs; };
    };

  };
}
