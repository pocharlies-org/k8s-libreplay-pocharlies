# LibrePlay: Ubuntu drain prerequisites

All active LibrePlay workloads are scheduled with
`node-pool=ks5-nvme`; completed historical Jobs intentionally retain their
immutable `topology=lan` pod templates and do not create running pods.

Before draining or removing node `ubuntu`:

1. Confirm Argo CD reports `libreplay` as `Synced` and `Healthy`.
2. Confirm Postgres, Meilisearch, MinIO, web and worker pods are Ready on KS5.
3. Confirm the web and worker PDBs each allow at least one voluntary disruption.
4. Confirm `/api/health` and `/api/health/deps` return HTTP 200.
5. Inspect the three LibrePlay Longhorn volumes. Do not force-delete replicas.

Storage gate observed on 2026-07-10: `libreplay-minio-data` was healthy but had
only two replicas, one on `ubuntu` and one on `ks5-cp-2`. Ubuntu must not be
drained until that volume has three healthy replicas distributed across KS5,
or an equivalent validated storage migration has completed. Postgres and
Meilisearch already had three healthy KS5 replicas at that checkpoint.
