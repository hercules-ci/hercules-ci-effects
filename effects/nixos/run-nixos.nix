{ nixos
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
        }
      ).config,
    profile ? "/nix/var/nix/profiles/system",
    sshDestination,
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
  checked (mkEffect (args // {
    inherit sshDestination;
    name = "nixos-${sshDestination}";
    inputs = (args.inputs or []) ++ [ openssh nix ];
    effectScript = ''
      ${args.effectScript or ""}
      nix-copy-closure --use-substitutes --to "$sshDestination" ${toplevel}
      ssh "$sshDestination" "$remoteScript"
    '';
    remoteScript = ''
      ${args.remoteScript or ""}
      set -euo pipefail
      nix-env -p ${profile} --set ${toplevel}
      ${toplevel}/bin/switch-to-configuration switch
    '';
    passthru = {
      prebuilt = toplevel;
    } // passthru;
    dontUnpack = args.dontUnpack or true;
  }))
