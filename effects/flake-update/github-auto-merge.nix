{ lib, autoMergeMethod }:

''
  echo Enabling auto-merge...

  repoDetail="$(gh repo view --json owner,name)"
  owner="$(echo $repoDetail | jq -r .owner.login)"
  name="$(echo $repoDetail | jq -r .name)"

  prNumber="$(sed <$TMPDIR/pr.out -n -e 's^https*://.*/pull/\([0-9][0-9]*\).*^\1^p')"
  if [[ 1 != "$(echo "$prNumber" | wc -l)" ]]; then
    echo "Couldn't figure out the PR number from `gh` command output."
    echo "This seems like an internal error in"
    echo "  hercules-ci-effects / flake-update"
    echo "You could disable `githubAutoMerge` to avoid this error, or"
    echo "ignore the error until fixed."
    exit 1
  fi

  prResponse="$(gh api graphql \
    --field prNumber="$prNumber" \
    --field owner="$owner" \
    --field name="$name" \
    -f query=${lib.escapeShellArg ''
      query ($prNumber: Int!, $owner: String!, $name: String!) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $prNumber) {
            id
            viewerCanEnableAutoMerge
          }
          autoMergeAllowed
        }
      }
    ''})"
  prId="$(echo "$prResponse" | jq .data.repository.pullRequest.id)"

  if [[ true != $(echo "$prResponse" | jq .data.repository.autoMergeAllowed) ]]; then
    echo
    echo "Auto-merge is not allowed on this repository."
    echo
    echo "To enable auto-merge on the repository, follow the steps in"
    echo
    echo "https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request#enabling-auto-merge"
    echo
    echo "and then add a branch protection rule for the default branch,"
    echo "with required status:"
    echo
    echo "https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches#require-status-checks-before-merging"
    exit 1
  fi

  if [[ -z "''${prId:-}" ]]; then
    echo "Could not find GraphQL id for PR."
    exit 1
  fi

  prId="$(gh api graphql \
    --field prId="$prId" \
    -f query=${lib.escapeShellArg ''
      mutation SetAutoMerge ($prId: ID!) {
        enablePullRequestAutoMerge(input: {pullRequestId: $prId, mergeMethod: ${lib.toUpper autoMergeMethod}}) {
          clientMutationId
        }
      }
    ''} \
    --jq .data.repository.pullRequest.id 2> >(tee $TMPDIR/automerge.err 1>&2) \
    || touch $TMPDIR/automerge.failed)"
  if [[ -e $TMPDIR/automerge.failed ]]; then
    if grep -F 'is in clean status' <$TMPDIR/automerge.err; then
      echo "The PR is already in clean status. Merging."
      gh pr merge "$prNumber" --${autoMergeMethod}
      merged=1
    else
      echo
      echo "error: Enabling auto-merge failed."
      echo
      echo "Note that you auto-merge must be enabled in the repository settings,"
      echo "and a branch protection rule must be configured for the branch to"
      echo "merge into."
      echo
      echo Created PR:
      cat $TMPDIR/pr.out
      exit 1
    fi
  else
    echo
    echo Created PR:
    cat $TMPDIR/pr.out
  fi
''