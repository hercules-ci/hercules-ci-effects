{ pkgs, hci-effects }:

rec {
  inherit (pkgs) lib;

  # Minimal example
  example =
    hci-effects.cargoPublish {
      src = ./test;
      secretName = "some-secret";
    };

  tests = ok:
    assert example.isEffect or null == true;

    # It instantiates
    assert lib.isString example.drvPath;

    ok;
}
