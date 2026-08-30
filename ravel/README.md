# Ravel

[Ravel](https://github.com/NOFireAI/ravel) is an open-source, multi-tenant
telemetry database written in Rust. It stores logs, metrics and traces, and
answers analytical SQL over the logs signal.

## What is different about this entry

**Ravel has no local-disk storage mode.** S3-compatible object storage is its
only durable backend, and every compute process is disposable. That is
architecture, not tuning, so this benchmark cannot be run self-contained on a
single VM the way an embedded engine can: it needs a bucket and credentials.

The consequence for the numbers is worth stating plainly rather than leaving a
reader to discover it: **every query in this entry pays object-store round
trips that a local-disk system does not.** Ravel is not tuned to hide that, and
the result should be read as "an S3-native engine on this workload", not as a
like-for-like comparison against an engine reading from an attached SSD. The
`data_size` reported here is bytes stored in the bucket, measured with
`aws s3 ls --summarize`, not bytes on the VM.

## Prerequisites

Set these before running `benchmark.sh`:

```sh
export RAVEL_S3_BUCKET=...      # bucket to store into
export RAVEL_S3_REGION=...      # same region as the VM, or the numbers are latency-dominated
export RAVEL_S3_ACCESS_KEY=...
export RAVEL_S3_SECRET_KEY=...
export RAVEL_TENANT=...         # optional, defaults to `clickbench`
```

The **tenant** must be unused in that bucket. Ravel has no "drop tenant"
command, so loading into a tenant that already holds objects would measure a
load on top of existing state and report a `data_size` that includes it. The
bucket itself may hold other tenants: `data-size` resolves this tenant's hashed
prefix from the catalog and sums only that prefix, which is the tenant's whole
durable footprint (data objects, commit records, manifests, catalog snapshots).

The AWS CLI is required for `data-size`. `RAVEL_REF` pins the Ravel commit that
is built (default `main`); the resolved commit is written to `ravel-commit.txt`
so a result can be traced to a build.

## Loading

The Parquet file is imported with `ravel-cli load --parquet` and the checked-in
column mapping at `benchmarks/clickbench/hits.mapping.toml` in the Ravel repo.
After the import, `catalog fold` seals the ingested hours into the catalog
snapshot. That step is inside the measured load window: queries resolve against
the snapshot, so a run without it would be querying a state no steady-state
deployment serves from, and would be reporting a faster load than the one that
produced the queryable dataset.

## Queries

`queries.sql` is generated from Ravel's own checked-in ClickBench corpus, which
carries each statement's upstream ClickBench query number, so the ordering here
is the upstream Q1..Q43 ordering rather than a local one.

The statements are the 43 ClickBench queries with four mechanical adaptations,
listed in full so a reviewer can diff them against any other entry:

1. The table is named `logs`, Ravel's logs signal, rather than `hits`.
2. Column identifiers are double-quoted, because they are case-sensitive
   attribute names.
3. Five queries use `ts`, the record's timestamp field, where upstream uses
   `EventTime`. Ravel's log records carry one canonical timestamp; the mapping
   at `hits.mapping.toml` populates it from the source `EventTime` column.
4. Seven queries compare `"EventDate"` against integer day numbers
   (`>= 15900`) where upstream compares against date literals
   (`>= '2013-07-14'`). The mapping stores `EventDate` as the source Parquet's
   underlying integer day number, and 15900 is the same day as `2013-07-14`.
   No predicate is widened or narrowed by this.

Nothing else is changed: no query is rewritten to a cheaper shape, none is
dropped, and none is reordered.

Ravel's SQL endpoint takes an explicit time window and defaults to the last
hour, so `query` sends a window spanning the whole dataset. Without it every
query would legitimately match nothing, since the hits rows carry 2013
timestamps.

## Known refusals

**Q33 is refused, and reports `null`.** It groups by `(WatchID, ClientIP)`,
which on this dataset is very nearly unique per row: 99,997,493 groups from
99,997,497 rows. The aggregate state is therefore O(rows), and Ravel enforces a
hard per-query memory ceiling with spilling disabled, so the query is refused
with a typed error rather than completing. This is a deliberate property, not a
crash: budget exhaustion is an error and never a partial result.

A measured run needed roughly 18 GB of resident memory to complete Q33 with the
ceiling raised, against the 8 GiB default. Bounded spill for eligible operators
is being added; until it lands, this entry reports the refusal honestly rather
than raising the ceiling to make one query pass.
