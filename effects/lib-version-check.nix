{ lib,
  revInfo ? "",
  versionSource ? "passed to hercules-ci-effects",
  # A component name to be used in error messages. Adds context about the way
  # in which hercules-ci-effects gets invoked.
  component ? "hercules-ci-effects",
}:

let
  # A best effort, lenient estimate. Please use a recent nixpkgs.
  minVersion = "22.05";

  checkVersion = if builtins.compareVersions lib.version minVersion < 0
    then
      abort ''
        ${component}: The nixpkgs version ${versionSource} is too old.
        The version of nixpkgs must be at least ${minVersion},
        but the actual version is ${lib.version}${revInfo}.
      ''
    else
      x: x;

in checkVersion
