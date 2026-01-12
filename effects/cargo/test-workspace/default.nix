# Test for multi-crate workspace publishing.
# To run, uncomment the cargoPublishWorkspaceDryRun line in flake-dev.nix, then:
#   hci effect run onPush.default.effects.tests.cargoPublishWorkspaceDryRun
{
  pkgs,
}:
let
  effects = import ../../default.nix effects pkgs;
  inherit (effects) cargoPublish;
in
cargoPublish {
  src = ./.;
  # secretName not needed for dry-run
  dryRun = true;
  # Check all packages match this version
  assertVersions = "0.1.0";
}
