{ pkgs }:
let
  effects = import ../../default.nix effects pkgs;
  inherit (effects) cargoPublish;
in
cargoPublish {
  src = ./.;
  secretName = "staging.crates.io-hci-testing";
  registryURL = "https://github.com/rust-lang/staging.crates.io-index";
  postUnpack = ''
    # Crates are immutable, so we create a unique version every time we publish,
    # containing the current timestamp.
    setVersion() {
      local version="0.1.$(date +%s)"
      echo "Setting version to $version"
      sed -i "s/version = \"0.1.0\"/version = \"$version\"/g" Cargo.toml
      if ! grep $version Cargo.toml; then
        echo 'failed to replace version??'
        find .
        exit 1
      fi
      # The lock will have a stale version
      cargo check
    }
    (cd $sourceRoot && setVersion)
  '';
}
