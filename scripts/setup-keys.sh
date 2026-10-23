#!/bin/sh
# Usage: scripts/setup-keys.sh [KEY_DIR]
# Generates the P-256 key pair CI uses to sign check results. The private key goes to
# KEY_DIR (default ~/.config/witnessed-examples, mode 0600), never into the repository; the
# public key goes to .witnessed/policy/keys/ci.pub.pem. Prints the gh commands that store
# the private key as an environment secret; it does not run them.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
key_dir=${1:-"$HOME/.config/witnessed-examples"}
key="$key_dir/ci.key.pem"
pub="$root/.witnessed/policy/keys/ci.pub.pem"

if [ -e "$key" ]; then
  echo "setup-keys: $key already exists; remove it first to generate a new key" >&2
  exit 1
fi
mkdir -p "$key_dir" "$(dirname "$pub")"
chmod 700 "$key_dir"
umask 077
openssl ecparam -name prime256v1 -genkey -noout | openssl pkcs8 -topk8 -nocrypt -out "$key"
openssl ec -in "$key" -pubout -out "$pub" 2>/dev/null
chmod 644 "$pub"

cat <<MSG
Private key: $key
Public key:  $pub (commit it)

Run these to configure GitHub (needs admin on the repository):
  gh api -X PUT repos/Druidder-Labs/witnessed-examples/environments/assurance-signing \\
    -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true'
  gh api -X POST repos/Druidder-Labs/witnessed-examples/environments/assurance-signing/deployment-branch-policies -f name=main
  gh secret set WITNESSED_ATTESTATION_KEY --env assurance-signing --repo Druidder-Labs/witnessed-examples < "$key"
  gh variable set WITNESSED_REV --repo Druidder-Labs/witnessed-examples --body <full commit id of witnessed with verify-change>
MSG
