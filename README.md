# hercules-ci-effects
Expressions to change the world (just a tiny bit)

# About the project

Hercules CI Effects as implemented by the agent are a fairly low-level interface
for executing programs that interact with the Nix store, centralized state and
the real world.

This repository provides useful abstractions and implementations to automate
tasks such as deployment.

# Getting started

## Prerequisites

 - You've [built](https://docs.hercules-ci.com/hercules-ci/getting-started/) your repo's `ci.nix` on Hercules CI

## Installation

- Import this repo in a project where you want to automate something.

- Expose the return value of one of the functions below as an attribute in your `ci.nix`.

See [the NixOS deployment guide](https://docs.hercules-ci.com/hercules-ci-effects/guide/deploy-a-nixos-machine.html) for an example.

# Usage

See the Nix Functions Reference and Bash Functions Reference on the [documentation site](https://docs.hercules-ci.com/hercules-ci-effects/).

Here's an example:

```nix
#ci.nix
{ src ? { ref = null; } }: {

  production = runIf (src.ref == "refs/heads/master") (
    effects.runNixOps {
      name = "production";
      src = pkgs.lib.cleanSource ./.; # NixOps reads your Nix files
      networkFiles = ["network.nix"];
      secretsMap.aws = "production-aws";
    }
  );
}
```

# License

Distributed under the  Apache License Version 2.0. See LICENSE for more information.

# Contact

Email: support@hercules-ci.com
Twitter: [@hercules_ci](https://twitter.com/hercules_ci)

## Acknowledgements

 * [hercules-ci-effects Contributors](https://github.com/hercules-ci/hercules-ci-effects/graphs/contributors)
 * [Nix](https://nixos.org/nix)
 * [NixOps](https://nixos.org/nixops)
 * [nix-darwin](https://nixos.org/LnL7/nix-darwin)
