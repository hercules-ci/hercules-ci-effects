{
  description = "Hercules CI Effects";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.hercules-ci-agent.url = "hercules-ci-agent";

  outputs = inputs@{ self, nixpkgs, hercules-ci-agent, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; }
      ({ withSystem, ... }: {
        imports = [
          ./flake-public-outputs.nix
          ./flake-dev.nix
        ];
      });
}
