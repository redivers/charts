# Rediver Helm Charts

Helm charts for [Rediver](https://rediver.ai), served from a custom-domain Helm
repository backed by GitHub Pages.

## Usage

```bash
helm repo add rediver https://helm.rediver.ai
helm repo update
helm search repo rediver
```

Then install a chart, e.g. the connector:

```bash
helm install my-connector rediver/connector \
  --namespace rediver --create-namespace \
  --set rediver.token=<cluster-token>
```

## Available charts

| Chart | Description |
|---|---|
| [`connector`](./charts/connector) | Outbound agent bridging external platforms (GitLab, etc.) with the Rediver backend. |

## How releases work

- Charts live under [`charts/<name>/`](./charts).
- On push to `main`, the [`release-charts`](./.github/workflows/release.yml) workflow runs
  [`helm/chart-releaser-action`](https://github.com/helm/chart-releaser-action): it packages
  each chart whose `version` changed, publishes a GitHub Release with the `.tgz`, and updates
  `index.yaml` on the `gh-pages` branch.
- GitHub Pages serves `gh-pages` at the custom domain **helm.rediver.ai** (see `CNAME`).
- The `index.yaml` references the `.tgz` assets hosted on GitHub Releases.

### Contributing a change

1. Edit the chart under `charts/<name>/`.
2. **Bump `version`** in that chart's `Chart.yaml` (SemVer) — releases are keyed off the version.
3. Open a PR. The [`lint-charts`](./.github/workflows/lint.yml) workflow validates it.
4. Merge to `main`. The release workflow publishes the new version automatically.

## Adding a new chart

Create `charts/<name>/` with the standard Helm layout (`Chart.yaml`, `values.yaml`,
`templates/`). No workflow changes needed — chart-releaser discovers every subdirectory
of `charts/`.
