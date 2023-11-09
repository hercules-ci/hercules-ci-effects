{
  description = "Hercules CI Effects";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; }
      ({ withSystem, ... }: {
        imports = [
          ./flake-public-outputs.nix
          ./flake-dev.nix
        ];
      });
}
