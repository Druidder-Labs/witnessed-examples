# witnessed-examples

A Terraform repository that runs `witnessed verify-change` as a required check on every pull request. Three scenario pull requests show a change that passes, a sensitive change that waits for an independent approval, and a pull request that tries to weaken the policy that judges it.

Background: [witnessed docs/assurance](https://github.com/Druidder-Labs/witnessed/tree/main/docs/assurance).

## Layout

```
.github/workflows/agent-change-assurance.yml  checks -> attest -> verify, on pull_request_target
.github/CODEOWNERS                           .github/ and .witnessed/ need the owner's review
.witnessed/policy/change.rego                the policy, read from the base commit
.witnessed/policy/keys/ci.pub.pem            written by scripts/setup-keys.sh
infra/                                       SNS topic and an IAM role (Terraform 1.17.0, aws 6.70.0)
scenarios/                                   files each scenario pull request copies over the repository
scripts/setup-keys.sh                        generates the CI signing key pair
```

Nothing here is applied to AWS. CI runs `terraform fmt`, `terraform init -backend=false`, `terraform validate` and `checkov`; no job has AWS credentials.

## Prerequisites

- A commit of `Druidder-Labs/witnessed` that contains `verify-change`, pushed to any branch of that repository. Its full commit id goes into `WITNESSED_REV`.
- Admin access to this repository, and `gh` authenticated.
- A second GitHub account with write access, to approve. GitHub does not let the author approve their own pull request, and the policy does not count the author or a commit author.

## Setup

1. Generate the signing key. The private key stays in `~/.config/witnessed-examples/`.

   ```
   scripts/setup-keys.sh
   ```

2. Commit everything, including `.witnessed/policy/keys/ci.pub.pem`, and push to `main`. The workflow must be on `main` before the first pull request: `pull_request_target` runs the default branch's copy.
3. Run the `gh` commands the script printed. They create the `assurance-signing` environment, restrict it to `main`, store the private key as its secret, and set `WITNESSED_REV`. A workflow that a pull request adds runs on the pull request's ref, so the environment refuses it the key; `pull_request_target` runs in the context of `main` and gets it.
4. In Settings, Rules, Rulesets, create a branch ruleset for the default branch:
   - Require a pull request before merging, with "Require review from Code Owners".
   - Require status checks to pass: add `verify`, source GitHub Actions.
   - Block force pushes.

## Scenarios

Each scenario is one branch and one pull request. From an up-to-date `main`:

```
git switch -c demo/01-topic-display-name
cp -R scenarios/01-topic-display-name/. .
git add -A && git commit -m "chore(infra): rename the deploy topic display name"
git push -u origin demo/01-topic-display-name
gh pr create --fill
```

| Scenario | Change | Expected `verify` result |
| --- | --- | --- |
| `01-topic-display-name` | `display_name` of the SNS topic in `infra/sns.tf` | `VERIFIED`: requires `terraform-fmt` and `terraform-validate`; no IAM block in the changed file, so no approval |
| `02-iam-publish-policy` | Adds an `aws_iam_role_policy` and its policy document in `infra/iam.tf` | `INCONCLUSIVE` until the second account approves: `review.independent-approval` and `check.terraform-security-scan` apply. After the approval, re-run the `verify` job: `VERIFIED` |
| `03-weaken-policy` | The same IAM change, plus a policy without the approval rule | `INCONCLUSIVE`: the policy is read from `main`, so the approval rule still applies, and `verifier.policy-change-approved` requires an independent approval for the policy edit. Code owners must also review |

Reviews submitted after a run are read only when `verify` runs again: open the pull request's Checks tab and re-run the `verify` job. A new push starts a new run for the new head commit.

Each run writes the report to the job summary and uploads `change-verification/report.json`.

## Reproduce a decision locally

Download the `attestations` artifact and the run's `report.json`, then:

```
witnessed collect github-pr --repository Druidder-Labs/witnessed-examples --number <n> -o pull-request.json
witnessed verify-change --commit <head sha> --base <base sha> --repository Druidder-Labs/witnessed-examples \
  --policy .witnessed/policy --policy-ref <base sha> \
  --attestation attestations/ --pull-request pull-request.json --format json
```

`input_digest` matches the CI report when the reviews have not changed since the run.

## What this does not show

- Keyless signing: the CI key is a stored secret.
- An agent's session bundle: the scenarios are plain commits.
- Changes outside `infra/`: `checkov` and `terraform validate` cover `infra/` only, and `terraform fmt` covers the repository.
