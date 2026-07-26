#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chart="$repo_root/charts/connector"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "connector chart test failed: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || fail "$file does not contain: $expected"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    fail "$file unexpectedly contains: $unexpected"
  fi
}

assert_render_fails() {
  local name="$1"
  local expected="$2"
  shift 2
  local output="$tmp_dir/$name.error"
  if helm template test "$chart" "$@" >"$output" 2>&1; then
    fail "$name rendered successfully"
  fi
  assert_contains "$output" "$expected"
}

default_manifest="$tmp_dir/default.yaml"
helm template test "$chart" \
  --set-string rediver.token=test-token >"$default_manifest"

assert_contains "$default_manifest" 'image: "ghcr.io/redivers/connector:2.0.3"'
for name in \
  REDIVER_URL \
  REDIVER_TOKEN \
  LOG_LEVEL \
  SHUTDOWN_GRACE_SECONDS \
  ARTIFACT_ENCRYPTION \
  GITLAB_PROJECTS_PER_PAGE; do
  assert_contains "$default_manifest" "name: $name"
done
for removed in --data-dir DATA_DIR WORKERS QUEUE_SIZE; do
  assert_not_contains "$default_manifest" "$removed"
done
assert_contains "$default_manifest" 'runAsUser: 999'
assert_contains "$default_manifest" 'runAsGroup: 999'
assert_contains "$default_manifest" 'fsGroup: 999'

custom_manifest="$tmp_dir/custom.yaml"
helm template test "$chart" \
  --set-string rediver.token=test-token \
  --set config.threads=4 \
  --set config.logLevel=debug \
  --set config.shutdownGraceSeconds=45 \
  --set config.artifactEncryption=true \
  --set-string gitlab.url=https://gitlab.example.com \
  --set-string gitlab.token=gitlab-token \
  --set gitlab.projectsPerPage=5 >"$custom_manifest"

for name in \
  THREADS \
  LOG_LEVEL \
  SHUTDOWN_GRACE_SECONDS \
  ARTIFACT_ENCRYPTION \
  GITLAB_URL \
  GITLAB_TOKEN \
  GITLAB_PROJECTS_PER_PAGE; do
  assert_contains "$custom_manifest" "name: $name"
done
for value in '"4"' '"debug"' '"45"' '"true"' '"https://gitlab.example.com"' '"5"'; do
  assert_contains "$custom_manifest" "value: $value"
done

existing_secret_manifest="$tmp_dir/existing-secret.yaml"
helm template test "$chart" \
  --set-string existingSecret=connector-secret >"$existing_secret_manifest"
assert_not_contains "$existing_secret_manifest" 'kind: Secret'
assert_contains "$existing_secret_manifest" 'name: connector-secret'
assert_contains "$existing_secret_manifest" 'name: GITLAB_TOKEN'
assert_contains "$existing_secret_manifest" 'optional: true'

read_only_manifest="$tmp_dir/read-only.yaml"
helm template test "$chart" \
  --set-string rediver.token=test-token \
  --set securityContext.readOnlyRootFilesystem=true >"$read_only_manifest"
assert_contains "$read_only_manifest" 'mountPath: /home/connector'
assert_contains "$read_only_manifest" 'mountPath: /tmp'

assert_render_fails missing-token 'rediver.token is required'
assert_render_fails empty-url 'rediver.url must not be empty' \
  --set-string rediver.token=test-token \
  --set-string rediver.url=
assert_render_fails gitlab-token-without-url \
  'gitlab.url and gitlab.token must be set together' \
  --set-string rediver.token=test-token \
  --set-string gitlab.token=gitlab-token
assert_render_fails gitlab-url-without-token \
  'gitlab.url and gitlab.token must be set together' \
  --set-string rediver.token=test-token \
  --set-string gitlab.url=https://gitlab.example.com
assert_render_fails invalid-threads 'config.threads must be a positive integer' \
  --set-string rediver.token=test-token \
  --set config.threads=0
assert_render_fails invalid-log-level \
  'config.logLevel must be one of debug, info, warn, error' \
  --set-string rediver.token=test-token \
  --set-string config.logLevel=verbose
assert_render_fails invalid-shutdown-grace \
  'config.shutdownGraceSeconds must be a positive integer' \
  --set-string rediver.token=test-token \
  --set config.shutdownGraceSeconds=0
assert_render_fails invalid-project-page-size \
  'gitlab.projectsPerPage must be between 1 and 100' \
  --set-string rediver.token=test-token \
  --set gitlab.projectsPerPage=101

chart_metadata="$chart/Chart.yaml"
chart_readme="$chart/README.md"
assert_contains "$chart_metadata" 'version: 0.3.2'
assert_contains "$chart_metadata" 'appVersion: "2.0.3"'
for documented_value in \
  '`config.threads`' \
  '`config.logLevel`' \
  '`config.shutdownGraceSeconds`' \
  '`config.artifactEncryption`' \
  '`gitlab.projectsPerPage`'; do
  assert_contains "$chart_readme" "$documented_value"
done
assert_contains "$chart_readme" 'Required unless `existingSecret` is set.'
assert_contains "$repo_root/.github/workflows/lint.yml" \
  './tests/connector-chart.test.sh'

echo "connector chart rendering tests passed"
