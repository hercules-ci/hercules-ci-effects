{
  description = "Development inputs used by ../flake-dev.nix";

  inputs = {
    nixpkgs-nixops2.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # match ../flake.nix (usually); improve after nix#7730
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { ... }:
    {
      # deps only; use ../flake.nix for everything
    };
}
