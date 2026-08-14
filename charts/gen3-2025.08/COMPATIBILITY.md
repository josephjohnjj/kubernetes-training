# Gen3 2025.08 compatibility baseline

This directory vendors the official `gen3-0.2.21` Helm release and pins the
enabled Gen3 applications to the matching `2025.08` container release. The old
`charts/gen3` directory is intentionally retained as a rollback reference.

The environment overlays make four compatibility corrections:

1. Indexd settings are mounted in the image's existing `/indexd` application
   directory and loaded by a chart-managed WSGI bootstrap. The bootstrap passes
   those settings explicitly to `get_app()`; without it, this image loads its
   localhost database defaults.
2. Tube receives the Elasticsearch host, port, protocol, username, and password
   as separate environment variables.
3. Guppy, Tube, and Portal all use the same `dev_case` index and generic case
   schema.
4. An Argo CD PreSync job creates the two empty Elasticsearch indices if they
   do not exist. This lets Guppy start before the first Tube run.
5. Fence maintenance jobs inherit the same database environment as the Fence
   deployment instead of falling back to PostgreSQL on localhost.

Argo CD uses this chart through
`argocd/applications/gen3/gen3.yaml`. Once these repository changes reach the
remote `main` branch, automated sync applies the release.

## Data flow

Data is not uploaded to Elasticsearch or HDFS directly:

1. Submit records through Sheepdog using the generic Gen3 dictionary.
2. Sheepdog stores graph data in PostgreSQL.
3. Start a Tube run from the `etl-cronjob` CronJob.
4. Tube reads Sheepdog's PostgreSQL data and writes `dev_case` to Elasticsearch.
5. Guppy serves that index to Portal.

Create an immediate Tube run with:

```sh
kubectl -n gen3 create job --from=cronjob/etl-cronjob etl-manual-$(date +%s)
```

## Verification

```sh
kubectl -n argocd get application gen3
kubectl -n gen3 get deployments
kubectl -n gen3 logs deployment/indexd-deployment --all-containers --tail=100
kubectl -n gen3 logs deployment/guppy-deployment --all-containers --tail=100
kubectl -n gen3 logs deployment/portal-deployment --all-containers --tail=100
```

Local chart validation is available through `./validate.sh`.

## Secret follow-up

The existing environment values contain credentials in Git. This migration
preserves them to avoid changing infrastructure and application versions at the
same time. Rotate them and move them to Kubernetes or External Secrets after
the compatibility rollout is healthy.
