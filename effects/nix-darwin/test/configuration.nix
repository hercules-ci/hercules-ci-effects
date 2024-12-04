{ lib, pkgs, ... }:
{
  system.stateVersion = 5;
  environment.systemPackages = [ pkgs.hello ];
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  # Paper over some flake vs non-flake differences so that the tests can compare toplevel
  system.darwinVersionSuffix = lib.mkForce "TEST-DARWIN-VERSION-SUFFIX";
  system.darwinRevision = lib.mkForce "TEST-DARWIN-REVISION";
  system.nixpkgsRevision = lib.mkForce "TEST-NIXPKGS-REVISION";
  system.nixpkgsVersion = lib.mkForce "TEST-NIXPKGS-VERSION";
  system.nixpkgsVersionSuffix = lib.mkForce "TEST-NIXPKGS-VERSION-SUFFIX";
  system.checks.verifyNixPath = lib.mkForce false;

  imports = [
    ({ pkgs, ... }: {
      options = {
        expose.pkgs = lib.mkOption {
          type = lib.types.raw;
          default = pkgs;
          description = "Expose pkgs to the test";
          readOnly = true;
        };
      };
    })
  ];

}
