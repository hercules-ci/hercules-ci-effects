{ nixos
, effects
, lib
, mkEffect
, openssh
, nix
, path
}:
let
  inherit (lib) optionalAttrs isAttrs;
in
args@{
    configuration ? throw "effects.runNixOS: you must provide a configuration (or a fully evaluated configuration in `config`)",
    system ? throw "effects.runNixOS: you must provide a `system` parameter (or a fully evaluated configuration in `config`)",
    nixpkgs ? path,
    config ?
      (
        import (nixpkgs + "/nixos/lib/eval-config.nix") {
          modules = [configuration];
          inherit system;
        }
      ).config,
    profile ? "/nix/var/nix/profiles/system",
    ssh,
    passthru ? {},
    ...
  }:
  let
    checked =
      if !(config ? environment.systemPackages)
      then throw "effects.runNixOS expects `config` to be an already evaluated configuration, like the `config` variable that's used in NixOS modules. Perhaps you intended to write `configuration` instead of `config`?"
      else x: x;
    inherit (config.system.build) toplevel;
  in
  checked (mkEffect (removeAttrs args ["configuration" "system" "nixpkgs" "ssh"] // {
    name = "nixos-${ssh.destination}";
    inputs = [
      # For user setup
      openssh
    ];
    effectScript = ''
      ${args.effectScript or ""}
      ${effects.ssh ssh ''
        set -euo pipefail
        echo >&2 "remote nix version:"
        nix-env --version >&2
        nix-env -p ${profile} --set ${toplevel}
        ${toplevel}/bin/switch-to-configuration switch
      ''}
    '';
    passthru = {
      prebuilt = toplevel // { inherit config; };
      inherit config;
    } // passthru;
    dontUnpack = args.dontUnpack or true;
  }))
