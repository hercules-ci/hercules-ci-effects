
# Hercules CI Effects `cargoPublish` test

This package exists for the purpose of testing the [`cargoPublish`](https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/cargoPublish.html) effect.

## `staging.crates.io`

We run this test against `staging.crates.io` so that we don't spam the more public `crates.io` registry.

## Running the test

Unfortunately, the existing setup and package name are tied to the Hercules CI organization.
You may request a token for the `hercules-ci-effects-test-*` crates from the Hercules CI team, <mailto:support@hercules-ci.com>.
(create a new token as in Initial Setup, with suitable name and expiry)

```sh
hci effect run onPush.default.effects.tests.cargoPublish --project github/hercules-ci/hercules-ci-effects
```

`--project` disables automatic upstream detection, for when the current branch's upstream is not the one for which you've set up the credentials.

## Initial Setup

We may have to repeat this, if the `staging.crates.io` registry is reset.

1. `nix shell nixpkgs#hci`
2. Log in and open https://staging.crates.io/settings/tokens/new
3. Enter:
 - **Name**: `hci-testing`
 - **Expiration**: no expiration
 - **Scopes**: **publish-new**, **publish-update**
 - **Crates**: `hercules-ci-effects-test-*`
4. Click `Generate Token` and keep the tab open
5. Run `hci secret add --project github/hercules-ci/hercules-ci-effects staging.crates.io-hci-testing --password token` and paste the token, close the tab
6. Edit the credentials file to remove the `"isDefaultBranch"` condition.
7. Run `hci effect run onPush.default.effects.tests.cargoPublish`, or see "Running the test" above.
   - This may fail if you haven't verified your email yet. Open [your profile](https://staging.crates.io/settings/profile) and click **Edit** under **User Email** to start verification.
8. Invite `hercules-ci-test-user` as **Owner** at https://staging.crates.io/crates/hercules-ci-effects-test-crate/settings.
9. Deploy the secret to the agents.
