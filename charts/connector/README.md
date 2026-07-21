# Rediver Connector Helm Chart

Deploys [Rediver Connector](https://github.com/redivers/connector), the
outbound agent that bridges Git providers with the Rediver backend. Chart
`0.3.1` deploys connector `2.0.1` by default.

The connector opens no inbound port, so this chart has no Service or Ingress.
Keep one replica per Rediver cluster token unless multiple distinct connector
registrations are intentional.

## Install

```bash
helm repo add rediver https://helm.rediver.ai
helm repo update

helm install my-connector rediver/connector \
  --namespace rediver \
  --create-namespace \
  --set-string rediver.token=<cluster-token>
```

`rediver.token` is required unless `existingSecret` references a Secret that
contains `REDIVER_TOKEN`.

## GitLab credentials

GitLab credentials may be stored in Rediver or supplied locally to the
connector. Job behavior is identical in both modes.

### Credential stored in Rediver

Leave both `gitlab.url` and `gitlab.token` empty. The connector obtains the
credential when Rediver sends a `sync_config` job.

### Connector-local credential

Set both values together. A partial local credential is rejected during Helm
rendering.

```bash
helm install my-connector rediver/connector \
  --namespace rediver \
  --create-namespace \
  --set-string rediver.token=<cluster-token> \
  --set-string gitlab.url=https://gitlab.example.com \
  --set-string gitlab.token=<personal-access-token>
```

The GitLab PAT needs `read_api` and `read_repository` access.

### Pre-existing Secret

Avoid storing tokens in Helm values or shell history by creating the Secret
before installation:

```bash
kubectl create secret generic rediver-connector \
  --namespace rediver \
  --from-literal=REDIVER_TOKEN=<cluster-token> \
  --from-literal=GITLAB_TOKEN=<personal-access-token>

helm install my-connector rediver/connector \
  --namespace rediver \
  --set-string existingSecret=rediver-connector \
  --set-string gitlab.url=https://gitlab.example.com
```

`existingSecret` must contain `REDIVER_TOKEN`. `GITLAB_TOKEN` is optional when
the GitLab credential is stored in Rediver, but is required in the Secret when
`gitlab.url` selects a connector-local credential. Helm cannot inspect an
existing Secret and therefore cannot validate that key before the pod starts.

## Runtime configuration

Example with lower GitLab page size for visible sync progress, debug logging,
four concurrent jobs, a longer shutdown grace period, and encrypted artifacts:

```bash
helm upgrade --install my-connector rediver/connector \
  --namespace rediver \
  --set-string rediver.token=<cluster-token> \
  --set config.threads=4 \
  --set config.logLevel=debug \
  --set config.shutdownGraceSeconds=60 \
  --set config.artifactEncryption=true \
  --set gitlab.projectsPerPage=5
```

`ARTIFACT_ENCRYPTION` defaults to `false`. Enable it explicitly when source
artifacts must be encrypted with the connector's AES-256-GCM compatibility
format before upload.

## Values

| Key | Environment | Default | Required | Description |
|---|---|---|---|---|
| `replicaCount` | — | `1` | No | Connector pod count. Keep one replica per cluster token. |
| `image.repository` | — | `ghcr.io/redivers/connector` | No | Container image repository. |
| `image.tag` | — | `""` → chart `appVersion` (`2.0.1`) | No | Explicit image tag override. Use `main` only for development deployments. |
| `image.pullPolicy` | — | `IfNotPresent` | No | Kubernetes image pull policy. |
| `imagePullSecrets` | — | `[]` | No | Image pull Secrets; the published GHCR image is public. |
| `rediver.url` | `REDIVER_URL` | `https://api.rediver.ai` | Yes, default provided | Non-empty Rediver API base URL. |
| `rediver.token` | `REDIVER_TOKEN` | `""` | **Required unless `existingSecret` is set.** | Rediver cluster token stored in the chart-created Secret. |
| `existingSecret` | — | `""` | No | Existing Secret containing `REDIVER_TOKEN` and, for local GitLab credentials, `GITLAB_TOKEN`. |
| `gitlab.url` | `GITLAB_URL` | `""` | Paired | GitLab base URL. With a chart-managed Secret, it must be set together with `gitlab.token`. |
| `gitlab.token` | `GITLAB_TOKEN` | `""` | Paired | GitLab PAT. With a chart-managed Secret, it must be set together with `gitlab.url`. Ignored when `existingSecret` is set. |
| `gitlab.projectsPerPage` | `GITLAB_PROJECTS_PER_PAGE` | `50` | No | Projects fetched per GitLab API page; integer from `1` through `100`. Progress is reported after each page. |
| `config.threads` | `THREADS` | `""` → `min(CPU × 2, 8)` | No | Maximum concurrent job executions. Empty delegates sizing to the connector. |
| `config.logLevel` | `LOG_LEVEL` | `info` | No | Minimum structured log level: `debug`, `info`, `warn`, or `error`. |
| `config.shutdownGraceSeconds` | `SHUTDOWN_GRACE_SECONDS` | `30` | No | Positive shutdown grace period before active handlers are interrupted. |
| `config.artifactEncryption` | `ARTIFACT_ENCRYPTION` | `false` | No | Enable AES-256-GCM source artifact encryption. |
| `extraEnv` | — | `[]` | No | Additional Kubernetes `EnvVar` objects, such as proxy configuration. |
| `strategy.type` | — | `Recreate` | No | Deployment strategy. `Recreate` avoids two connector registrations during rollout. |
| `serviceAccount.create` | — | `true` | No | Create a dedicated ServiceAccount. |
| `serviceAccount.name` | — | `""` | No | ServiceAccount name override. |
| `serviceAccount.annotations` | — | `{}` | No | ServiceAccount annotations. |
| `serviceAccount.automountServiceAccountToken` | — | `false` | No | Mount the Kubernetes API token into the connector pod. |
| `podSecurityContext` | — | non-root, `fsGroup: 999`, runtime-default seccomp | No | Pod security settings aligned with the published image's `connector` user. |
| `securityContext` | — | no privilege escalation, drop all capabilities, writable root filesystem | No | Container security settings. Read-only mode gets writable `/home/connector` and `/tmp` volumes. |
| `resources` | — | request `50m`/`64Mi`, memory limit `256Mi` | No | Container resource requests and limits. |
| `nodeSelector` | — | `{}` | No | Node selector. |
| `tolerations` | — | `[]` | No | Pod tolerations. |
| `affinity` | — | `{}` | No | Pod affinity rules. |
| `podAnnotations` | — | `{}` | No | Extra pod annotations. |
| `podLabels` | — | `{}` | No | Extra pod labels. |
| `nameOverride` / `fullnameOverride` | — | `""` / `""` | No | Resource name overrides. |

See [`values.yaml`](./values.yaml) for comments next to every value.

## Upgrade from chart 0.2.x

Connector `2.0.0` removes the old bounded queue and data-directory CLI API.
Update custom values before upgrading:

| Removed value | Replacement |
|---|---|
| `config.workers` / `WORKERS` | `config.threads` / `THREADS` |
| `config.queueSize` / `QUEUE_SIZE` | None; the executor queue is unbounded and polling respects available worker capacity. |
| `dataDir` / `DATA_DIR` / `--data-dir` | None; temporary repository workspaces use `/tmp` and are cleaned automatically. |

The chart no longer overrides `HOME` or the image user. The published image
runs as UID/GID `999` and owns its runtime directories. If
`securityContext.readOnlyRootFilesystem=true`, the chart supplies ephemeral
writable volumes at `/home/connector` and `/tmp` automatically.

Review two additional v2 defaults:

- Artifact encryption is disabled unless `config.artifactEncryption=true`.
- Connector-local GitLab credentials require both `gitlab.url` and
  `gitlab.token`; Rediver-managed credentials require neither.

## Uninstall

```bash
helm uninstall my-connector --namespace rediver
```
