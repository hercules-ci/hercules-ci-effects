{ mkEffect, openssh, nix, path }:

# Update a macOS machine with nix-darwin
#
# Use the nix-darwin installer first, then base the configuration off the
# generated ~/.nixpkgs/darwin-configuration.nix.
args@{

  # Source of nix-darwin
  nix-darwin,

  # Hostname to SSH to, to quote man 1 ssh:
  #   "destination, which may be specified as either [user@]hostname or a URI of
  #   the form ssh://[user@]hostname[:port.]"
  sshDestination,

  # Configuration module; file path or module expression
  # Start with a copy of ~/.nixpkgs/darwin-configuration.nix
  configuration,

  # Source of nixpkgs
  nixpkgs ? path,

  # System, defaults to x86_64-darwin
  system ? "x86_64-darwin",

  passthru ? {},

  # Remaining arguments are passed directly to mkEffect / mkDerivation
  ...
}:
let
  conf =
    import nix-darwin {
      inherit nixpkgs system configuration;
    };

  suffix =
    if conf.config.networking.hostName == null
      then ""
      else "-${conf.config.networking.hostName}";
in
mkEffect (args // {
  name = "nix-darwin${suffix}";
  inputs = [ openssh nix ];
  dontUnpack = true;
  passthru = passthru // {
    prebuilt = conf.system;
  };
  systemConfig = conf.system;
  effectScript = ''
    nix-copy-closure --to "$sshDestination" "$systemConfig"
    ssh "$sshDestination" "$systemConfig/sw/bin/darwin-rebuild activate"
  '';
})
