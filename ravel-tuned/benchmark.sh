#!/bin/bash
# Ravel: object-storage-native telemetry database, queried over SQL.
#
# Ravel keeps every durable byte in S3-compatible object storage; there is no
# local-disk storage mode. For this benchmark the store is a single-node RustFS
# that ./install downloads, starts and provisions on this machine's disk, with
# credentials it generates into a file readable by the current user only, so
# nothing is required from the operator and no key is stored in this
# repository. See README.md.
export BENCH_DOWNLOAD_SCRIPT="download-hits-parquet-single"

# The server is a daemon whose data survives a restart (it is in object
# storage), so the driver's defaults are right: restartable, durable, and the
# concurrent-QPS test applies.
#
# First start has to reach the object store, resolve the tenant and open the
# catalog, which is slower than a local-disk engine's start; give ./check room
# rather than failing a run on a cold control-plane round trip.
export BENCH_CHECK_TIMEOUT="${BENCH_CHECK_TIMEOUT:-600}"

# The tuned configuration (see README.md). ./start passes RAVEL_TUNED_ARGS to
# the server. The per-query memory pool is raised from the value derived on a
# 30 GB machine (about 8.2 GB) to 12 GiB, which lets the widest GROUP BY in the
# set (q33) complete instead of being refused.
export RAVEL_TUNED_ARGS="${RAVEL_TUNED_ARGS:---sql-max-query-bytes 12884901888}"
# The read cache's local-disk tier. It survives the driver's restart before
# each query, so a cold run can reuse the bytes earlier queries fetched.
export RAVEL_CACHE_DIR="${RAVEL_CACHE_DIR:-$PWD/cache}"
mkdir -p "$RAVEL_CACHE_DIR"

exec ../lib/benchmark-common.sh
