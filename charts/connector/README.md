# Rediver Connector Helm Chart

Deploys the [Rediver Connector](https://github.com/redivers/connector) — a lightweight
outbound agent that bridges external platforms (GitLab, etc.) with the Rediver backend.

The connector makes only **outbound** connections: it registers with the Rediver API and
runs sync/action loops. It exposes no inbound ports, so this chart ships no Service or Ingress.

## Install

```bash
helm repo add rediver https://helm.rediver.ai
helm repo update

helm install my-connector rediver/connector \
  --namespace rediver --create-namespace \
  --set rediver.token=<cluster-token>
```

### GitLab connector-managed token

Only when an integration uses `token_mode=connector`:

```bash
helm install my-connector rediver/connector \
  --namespace rediver --create-namespace \
  --set rediver.token=<cluster-token> \
  --set gitlab.token=<personal-access-token> \
  --set gitlab.url=https://gitlab.internal
```

### Using a pre-existing Secret

Avoid putting tokens in `values`/`--set` by creating the Secret yourself:

```bash
kubectl create secret generic rediver-connector \
  --namespace rediver \
  --from-literal=REDIVER_TOKEN=<cluster-token> \
  --from-literal=GITLAB_TOKEN=<personal-access-token>   # optional

helm install my-connector rediver/connector \
  --namespace rediver \
  --set existingSecret=rediver-connector
```

## Values

| Key | Default | Description |
|---|---|---|
| `replicaCount` | `1` | Number of connector pods. Each registers as a distinct connector — keep at 1 per cluster token. |
| `image.repository` | `ghcr.io/redivers/connector` | Image repository. |
| `image.tag` | `""` (chart `appVersion`) | Image tag. Use `main` for latest dev. |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy. |
| `rediver.url` | `https://api.rediver.ai` | Rediver API URL (`REDIVER_URL`). |
| `rediver.token` | `""` | Cluster token (`REDIVER_TOKEN`). **Required** unless `existingSecret` is set. |
| `gitlab.token` | `""` | GitLab PAT (`GITLAB_TOKEN`), connector-managed-token mode only. |
| `gitlab.url` | `""` | Self-managed GitLab base URL (`GITLAB_URL`). |
| `existingSecret` | `""` | Name of a pre-created Secret with `REDIVER_TOKEN` (+ optional `GITLAB_TOKEN`). |
| `config.workers` | `""` | Worker pool size (`WORKERS`). Empty = auto. |
| `config.queueSize` | `""` | Job queue size (`QUEUE_SIZE`). Empty = auto. |
| `dataDir` | `/data/rediver-connector` | Clone/archive working dir (`DATA_DIR`), backed by an ephemeral `emptyDir`. |
| `extraEnv` | `[]` | Extra environment variables (e.g. `HTTP_PROXY`). |
| `resources` | requests 50m/64Mi, limit 256Mi | Container resources. |
| `serviceAccount.create` | `true` | Create a dedicated ServiceAccount. |
| `podSecurityContext` / `securityContext` | non-root, drop ALL caps | Hardened defaults. |
| `nodeSelector` / `tolerations` / `affinity` | `{}` / `[]` / `{}` | Standard scheduling controls. |

See [`values.yaml`](./values.yaml) for the full list.

## Uninstall

```bash
helm uninstall my-connector --namespace rediver
```
