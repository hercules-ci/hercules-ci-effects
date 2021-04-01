{ lib, mkEffect, arion, docker, pkgs }:
let parentPkgs = pkgs;
in
args@{
  # Docker Compose project name
  name,

  # Optional. Directory with arion-compose.nix and arion-pkgs.nix files.
  #
  # Alternatively, you can specify modules and pkgs.
  directory ? null,

  # Arion compose modules, example: [ ./alternate-compose.nix ]
  # If you only specify modules, pkgs will default to the Nixpkgs that runArion linked to.
  modules ? [ (directory + "/arion-compose.nix") ],

  # Nixpkgs invocation
  #
  # If directory is not given, pkgs will default to the Nixpkgs that runArion linked to.
  # Example: import ./special-deployment-nixpkgs.nix {}
  pkgs ?
    if directory == null
    then parentPkgs
    else import (directory + "/arion-pkgs.nix"),

  # This parameter is intended for local development only and does not have a well-defined
  # meaning in the context of a remote deployment.
  uid ? builtins.throw "Attempt to use the uid module parameter. This parameter is intended for local development only.",

  hostNixStorePrefix ? "",

  # Remaining arguments are passed directly to mkEffect / mkDerivation
  ...

}:
let
  composition = arion.eval {
    inherit modules pkgs uid hostNixStorePrefix;
  };
  prebuilt = composition.config.out.dockerComposeYaml;
in
mkEffect (
    lib.filterAttrs (k: v: k != "modules" && k != "uid" && k != "pkgs") args
    // {
  name = "arion-${name}";
  inputs = [ arion docker ];
  dontUnpack = true;
  inherit prebuilt;
  passthru = (args.passthru or {}) // {
    prebuilt = prebuilt // { inherit (composition) config; };
    inherit (composition) config;
  };
  projectName = name;
  # TODO: make project name explicit in arion, remove pushd, popd, cp
  #       https://github.com/hercules-ci/arion/issues/54
  effectScript = ''
    mkdir "$projectName"
    pushd "$projectName" >/dev/null
    cp "$prebuilt" prebuilt.json
    arion --prebuilt-file prebuilt.json up -d
    popd >/dev/null
  '';
})
