{ effectVMTest, hci-effects }:

let

  baseUpdate = {
    imports = [ ../git-update.nix ];
    git.checkout.remote.url = "http://gitea:3000/test/repo";
    git.checkout.forgeType = "gitea";
    git.checkout.user = "test";

    git.update.branch = "update";
    git.update.pullRequest.enable = false;

    secretsMap.token = {
      type = "GitToken";
    };

    name = "update";
  };

in

# TODO: move some properties that are tested in flake-update to this test

effectVMTest {
  imports = [
    ../../testsupport/dns.nix
    ../../testsupport/gitea.nix
    ../../testsupport/setup.nix
  ];
  name = "git-update";
  effects = {
    update = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = ''
        echo updated >> file
        git add file
        git commit -m update
      '';
      git.update.baseMerge.enable = false;
    };
    update-uncommitted = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = ''
        echo updated >> file
        git add file
      '';
      git.update.baseMerge.enable = false;
    };
    update-unstaged = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = ''
        echo updated >> file
      '';
      git.update.baseMerge.enable = false;
    };
    update-no-commit = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = "";
      git.update.baseMerge.enable = false;
    };
    update-rebase = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = "
        echo updated >> file
        git commit -m 'update from update-rebase' file
      ";
      git.update.baseMerge.method = "rebase";
      git.update.baseMerge.enable = true;
      git.update.branch = "update";
    };
    update-rebase-simulate-concurrent-update = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = ''
        # remember where the concurrent thing will start
        git branch update-concurrent

        normal_update() {
          # this is the normal update
          echo updated >> file
          git commit -m 'update from update-rebase' file
        }

        # Simulate a concurrent update
        concurrent_update() {
          (
            # irl this would probably be a different machine, but a separate
            # clone is good enough.

            orig=$PWD
            cd ..
            cp -a "$orig" update-concurrent
            cd update-concurrent
            new=$PWD
            echo foo >bar.baz
            git add bar.baz
            git commit -m 'Add bar.baz - concurrently'
            git push origin HEAD:update

            echo "Simulated concurrent update done. Its view is:"
            git log --graph --oneline --decorate update-concurrent main origin/update origin/main

            cd ..
            rm -rf "$new"
          )
        }

        concurrent_update
        normal_update

        echo "Normal update mostly done (it's not pushed yet). Its view is:"
        git log --graph --oneline --decorate update main origin/update origin/main
      '';
      git.update.baseMerge.method = "rebase";
      git.update.baseMerge.enable = true;
      git.update.branch = "update";
    };
    update-fast-forward = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = "
        echo updated >> file
        git commit -m 'update from update-fast-forward' file
      ";
      git.update.baseMerge.method = "fast-forward";
      git.update.baseMerge.enable = true;
      git.update.branch = "update";
    };
    update-reset = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = ''
        echo updated >> file
        git commit -m 'update from update-reset' file
      '';
      git.update.baseMerge.method = "reset";
      git.update.baseMerge.enable = true;
      git.update.branch = "update";
    };
  };

  skipTypeCheck = true;

  testCases = ''
    token = gitea_admin_token

    repo = client.succeed("""
      curl -v --fail -X POST http://gitea:3000/api/v1/user/repos \
        -H 'Accept: application/json' -H 'Content-Type: application/json' \
        """ + f"-H 'Authorization: token {token}'" + """ \
        -d '{"name":"repo", "private":true}'
    """)
    print(repo)

    client.succeed("""
    (
      git clone http://gitea:3000/test/repo.git
      cd repo
      echo init > file
      git add file
      git commit -m 'file: init'
      git push
    ) 1>&2
    """)

    agent.succeed(f"echo {gitea_admin_password} | effect-update")

    client.succeed("""
      (
        set -x
        cd repo
        git fetch origin
        git checkout origin/update
        grep updated <file
      ) 1>&2
    """).rstrip()


    # repoName: name of the repo checkout directory on `client`
    def getRev():
      return client.succeed("""
        (
          cd repo
          git fetch origin
          git checkout origin/update
          git rev-parse HEAD
        )
      """).rstrip()

    repo_update_rev = getRev()

    with subtest("Not committing is ok"):
      r1 = getRev()
      agent.succeed(f"echo {gitea_admin_password} | effect-update-no-commit")
      assert getRev() == r1

    with subtest("Fail if work tree has unstaged changes"):
      r1 = getRev()
      agent.succeed(f"echo {gitea_admin_password} | (set -x; if effect-update-unstaged; then false; else [[ $? == 1 ]]; fi)")
      assert getRev() == r1

    with subtest("Fail if work tree has uncommitted changes"):
      r1 = getRev()
      agent.succeed(f"echo {gitea_admin_password} | (set -x; if effect-update-uncommitted; then false; else [[ $? == 1 ]]; fi)")
      assert getRev() == r1

    with subtest("Can rebase"):
      mainUpdateRev = client.succeed("""
        (
          set -x
          cd repo
          git fetch origin

          # Switch to main
          git checkout origin/main -B main

          # Set up a pre-existing update branch for the effect
          git checkout -B update
          touch from-fake-update
          git add from-fake-update
          git commit -m 'from-fake-update'
          # force to clear any updates from previous test cases
          git push --force --set-upstream origin update

          # Make main diverge from the update branch, so that a fast forward is not possible
          git checkout main
          echo other > other
          git add other
          git commit -m 'Add other'
          git push

          git log --graph --oneline --decorate update main origin/update origin/main
        ) 1>&2
        ( cd repo;
          git rev-parse origin/main
        )
      """).rstrip()
      agent.succeed(f"echo {gitea_admin_password} | effect-update-rebase")
      client.succeed(f"""
        (
          cd repo
          git fetch origin

          # When the update branch has been rebased onto the updated main, the
          # updated main occurs in the history of the update branch.
          git log --format=%H origin/update | grep {mainUpdateRev}
        )
      """)

    with subtest("rebase does not lose data when concurrent push happens"):
      agent.fail("""
        # check pipefail
        true | false
      """)

      # It would be ok for the effect to retry, in which we should change this
      # to expect succeed, and check that both the concurrent commit and the
      # update commit are present.
      # For now we just check that the effect fails, and rely on the user to
      # re-run it. It seems quite improbable to occur.

      agent.succeed(f"""
        (
          echo {gitea_admin_password} \
            | (! effect-update-rebase-simulate-concurrent-update 2>&1) \
            | tee concurrent-update.log
        )
      """)
      agent.succeed("""
        grep -E '\\[rejected\\].+update.+stale info' concurrent-update.log
      """)
      client.succeed("""
        (
          cd repo
          git fetch origin
          git log --graph --oneline --decorate update main origin/update origin/main
          git log origin/update | grep -F 'Add bar.baz - concurrently'
        ) 1>&2
      """)

    with subtest("Can fast-forward when update branch is behind"):
      # Clean slate: delete any existing update branch and ensure clean main
      client.succeed("""
        (
          set -x
          cd repo
          git fetch origin
          git push origin :update || true  # Delete remote update branch if it exists
          git branch -D update || true     # Delete local update branch if it exists

          # Ensure we're on a clean main branch
          git checkout origin/main -B main
          git reset --hard origin/main

          git status
        ) 1>&2
      """)

      # Run simple update to create fresh update branch
      agent.succeed(f"echo {gitea_admin_password} | effect-update")

      # Merge the update branch to main (simulating PR merge)
      client.succeed("""
        (
          set -x
          cd repo
          git fetch origin
          git merge origin/update --no-ff -m 'Merge update branch'
          git push
        ) 1>&2
      """)

      # Now make main move forward (new commits since last update)
      mainUpdateRev = client.succeed("""
        (
          set -x
          cd repo
          # Create a simple new file
          echo "new feature content" > new-feature-file
          git add new-feature-file
          git commit -m 'Add new feature to main'
          git push

          git log --graph --oneline --decorate main origin/main || true
        ) 1>&2
        ( cd repo; git rev-parse HEAD )
      """).rstrip()

      # Now fast-forward should succeed - update branch can fast-forward to main
      agent.succeed(f"echo {gitea_admin_password} | effect-update-fast-forward")

      client.succeed("""
        (
          cd repo
          git fetch origin

          # After fast-forward, update branch should include main's new commit plus the update
          git checkout origin/update
          test -f new-feature-file
          git log | grep 'update from update-fast-forward'
          git log | grep 'Add new feature to main'

          git log --graph --oneline --decorate origin/update origin/main
        ) 1>&2
      """)

    with subtest("Fast-forward fails when update branch has divergent commits"):
      # Clean slate and create update branch again
      client.succeed("""
        (
          set -x
          cd repo
          git fetch origin
          git push origin :update || true
          git branch -D update || true
        ) 1>&2
      """)

      # Create update branch with commits
      agent.succeed(f"echo {gitea_admin_password} | effect-update")

      # Save the hash of the update branch before main diverges
      updateBranchHash = client.succeed("""
        (
          cd repo
          git fetch origin
          git rev-parse origin/update
        )
      """).rstrip()

      # DON'T merge to main this time - let main diverge instead
      client.succeed("""
        (
          set -x
          cd repo
          git fetch origin
          git checkout origin/main -B main

          # Add divergent commit to main (different from what's in update branch)
          echo "main branch change" > main-divergent-file
          git add main-divergent-file
          git commit -m 'Conflicting change on main'
          git push

          git log --graph --oneline --decorate origin/update origin/main
        ) 1>&2
      """)

      # Fast-forward should fail because branches have diverged
      agent.fail(f"echo {gitea_admin_password} | effect-update-fast-forward")

      client.succeed("""
        (
          cd repo
          git fetch origin

          # Verify the branches are in diverged state
          git log --graph --oneline --decorate origin/update origin/main

          # Update branch should still exist (fast-forward failed, so no changes)
          git checkout origin/update

          # Main should have the divergent commit
          git checkout origin/main
          git log | grep 'Conflicting change on main'
        ) 1>&2
      """)

    with subtest("Reset succeeds even when branches have conflicting changes"):
      # This tests the scenario from feature request https://github.com/hercules-ci/hercules-ci-effects/issues/202:
      # 1. Update branch exists with flake.lock changes
      # 2. Someone pushes conflicting flake.lock changes to main
      # 3. Next scheduled run should succeed by resetting to main

      # Clean slate
      client.succeed("""
        (
          set -x
          cd repo
          git fetch origin
          git push origin :update || true
          git branch -D update || true
          git checkout origin/main -B main
          git reset --hard origin/main
        ) 1>&2
      """)

      # Create initial update branch (simulates first scheduled run)
      agent.succeed(f"echo {gitea_admin_password} | effect-update")

      # Add a manual commit to the update branch (simulates someone making changes to the PR)
      client.succeed("""
        (
          set -x
          cd repo
          git fetch origin
          git checkout origin/update -B update

          # Manual change that should be lost after reset
          echo 'manual PR change' > manual-file
          git add manual-file
          git commit -m 'Manual commit on update branch - should be lost'
          git push origin update

          git log --oneline origin/update
        ) 1>&2
      """)

      # Now simulate conflicting change on main (e.g., someone manually updates flake.lock)
      # This modifies the SAME file that the update script modifies
      mainNewRev = client.succeed("""
        (
          set -x
          cd repo
          git fetch origin
          git checkout origin/main -B main

          # Conflicting change: modify the same file the update script modifies
          echo 'manual change that conflicts' > file
          git add file
          git commit -m 'Manual conflicting change on main'
          git push

          git log --graph --oneline --decorate origin/update origin/main
        ) 1>&2
        ( cd repo; git rev-parse HEAD )
      """).rstrip()

      # Reset method should succeed where merge/rebase/fast-forward would fail
      agent.succeed(f"echo {gitea_admin_password} | effect-update-reset")

      # Verify the result
      client.succeed(f"""
        (
          set -x
          cd repo
          git fetch origin

          git log --graph --oneline --decorate origin/update origin/main

          # The update branch should be based on the NEW main (with the conflicting change)
          git checkout origin/update

          # Should have the update commit
          git log | grep 'update from update-reset'

          # The main's conflicting commit should be an ancestor
          git log --format=%H | grep {mainNewRev}

          # The file should have the update script's content, not the old update branch content
          # (because we reset to main and re-ran the update script)
          grep updated file

          # Verify that manual changes to the update branch are lost
          ! test -f manual-file
          ! git log | grep 'Manual commit on update branch'
        ) 1>&2
      """)
  '';
}
