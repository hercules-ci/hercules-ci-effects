{ lib }:
let
  inherit (lib) types;
  inherit (types) package oneOf lazyAttrsOf bool raw enum;

  derivationTree =
    oneOf [
      package
      (lazyTraversedAttrs { recurseByDefault = true; } derivationTree)
      bool  # allows recurseForDerivations to merge
      (enum [null])
      raw
    ] // { description = "a tree of attribute sets and derivations"; };
  lazyTraversedAttrs = { recurseByDefault }: t:
    let o = lazyAttrsOf t;
    in o // {
      check = v: o.check v && v.recurseForDerivations or recurseByDefault;
    };

  merge = t: vs:
    t.merge
      [ "test" "location" ]
      (lib.imap
        (i: v: { value = v; file = "test value number ${toString i}"; })
        vs);

  pkg = name:
    { type = "derivation"; outPath = builtins.toFile "${name}" ""; drvPath = builtins.toFile "${name}-drv" "kind of"; };

  ex1 = [
    { a = pkg "a"; }
    { b = pkg "b"; }
  ];
  ex2 = [
    { n.a = pkg "a"; }
    { n.b = pkg "b"; }
  ];
  ex2_1 = [
    { n = lib.recurseIntoAttrs { a = pkg "a"; }; }
    { n = lib.recurseIntoAttrs { b = pkg "b"; }; }
  ];
  ex2_2 = [
    { n = { a = pkg "a"; c = null; }; }
    { n = { b = pkg "b"; c = null; }; }
  ];
  ex2_3 = [
    { n = { a = pkg "a"; c = {}; }; }
    { n = { b = pkg "b"; c = {}; }; }
  ];
  ex3 = [
    # dontRecurseIntoAttrs could contain any kind of attribute set, so we can't merge this.
    { n = lib.dontRecurseIntoAttrs { a = 1; }; }
    { n = lib.dontRecurseIntoAttrs { b = 10; }; }
  ];

  traceId = x: builtins.trace x x;
  inherit (builtins) tryEval;
  fail = x: !(tryEval (traceId x)).success;

  tests = done:
    assert merge derivationTree ex1 == { a = pkg "a"; b = pkg "b"; };
    assert (merge derivationTree ex2).n == { a = pkg "a"; b = pkg "b"; };
    assert (merge derivationTree ex2_1).n == lib.recurseIntoAttrs { a = pkg "a"; b = pkg "b"; };
    assert (merge derivationTree ex2_2).n == { a = pkg "a"; b = pkg "b"; c = null; };
    assert (merge derivationTree ex2_3).n == { a = pkg "a"; b = pkg "b"; c = {}; };
    assert fail (merge derivationTree ex3).n;
    done;

in
{
  inherit derivationTree tests;
}
