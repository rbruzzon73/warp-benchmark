
# Warp Benchmark Script.

## General Notes:
   - The latest version of the script is warp-benchmark-v5.sh.
   - Benchmark tests were conducted in a test environment configured to align with OCP 4.16 and ODF 4.20.

## Notes warp-benchmark-V5.sh (LATEST version):
- warp image defined/assigned via WARP_IMAGE image.
- noobaa deduplication enable/disable via DEDUPLICATION_DISABLE variable.
- warp arguments can also be included via EXTRA variable.
- warp summary redirected to main container log stream.

## Notes warp-benchmark-V4.sh (DEPRECATED version):
- noobaa deduplication disabled before starting any warp banchmark test as highlighted in the example below:
   ~~~
   #------ Executing Workload: mixed - 2026-01-29 15:09:47 -------#
   [1/15] Ratio check
   [2/15] Disable noobaa deduplication
   deployment.apps/noobaa-endpoint updated
   Waiting for all endpoints to update to value '0'...
   --- Waiting for pods to scale... (Found 9, Expected 7) ---
   --- Waiting for pods to scale... (Found 10, Expected 7) ---
   --- Waiting for pods to scale... (Found 11, Expected 7) ---
   --- Waiting for pods to scale... (Found 12, Expected 7) ---
   --- Waiting for pods to scale... (Found 12, Expected 7) ---
   --- Waiting for pods to scale... (Found 11, Expected 7) ---
   --- Waiting for pods to scale... (Found 9, Expected 7) ---
   SUCCESS - All 7 endpoints are now set to 0.
   [3/15] Warp General Settings:
   StorageClass=openshift-storage.noobaa.io - Concurrent=7 - Size=1536KiB - noobaa Deduplication Disabled=true
   PUT Duration: 30s - GET Duration: 30s - MIXED Duration: 30s
   MIXED Ratio: 50% GETs - 50% PUTs - 0% DELETEs - 0% STATs
   ... omitted ...
   ~~~

## Notes warp-benchmark-V3.sh (DEPRECATED version):
- script updated with the option to run only GET or PUT tests:
- Usage: ./warp-benchmark-v2.sh [mixed|standard|get|put|all]

## Notes warp-benchmark-v2.sh (DEPRECATED version):
- warp-benchmark-v2.sh delete the old warp POD and regenerate a new one before starting all benchmark tests.
- warp url image updated to: quay.io/minio/warp:latest
- Warp ObjectBucketClaim recreated before starting the benchmarcs.
- Usage: ./warp-benchmark-v2.sh [mixed|standard|all]
- V2 expands the Benchmark tests to include the Mixed scenario, based on the percentage of GETs and PUTs:
   ~~~
   # GET and PUT benchmarcs
   [1/11] Creating namespace 'warp-benchmark'...
   [2/11] Deleting and re-creating ObjectBucketClaim ...
   [3/11] Waiting for OBC to be bound (provisioning bucket)...
   [4/11] Extracting credentials...
   [5/11] Clenup old Warp Running Pod
   [6/11] Deploying Warp Runner Pod...
   [7/11] Running GET Benchmark...
   [8/11] Sleeping for 30s before PUT benchmark...
   [9/11] Running PUT Benchmark...
   # MIXED benchmarcs
   [1/11] Creating namespace 'warp-benchmark'...
   [2/11] Deleting and re-creating ObjectBucketClaim warp-benchmark-bucket-tf7w...
   [3/11] Waiting for OBC to be bound (provisioning bucket)...
   [4/11] Extracting credentials...
   [5/11] Clenup old Warp Running Pod
   [6/11] Deploying Warp Runner Pod...
   [10/11] Running MIXED Benchmark...
   [11/11] Benchmarks Complete.
   ~~~ 
   
## Notes warp-benchmark-v1.sh (DEPRECATED version):
- warp-benchmark.sh is based on Warp MinIO's S3 benchmarking tool designed to measure and analyze object storage performance. 
- The Warp tool generats realistic workloads and provides detailed performance metrics for S3-compatible storage systems.
- This warp-benchmark.sh script executes PUT and GET benchmarks that can be customized and adjusted to meet various requirements regarding size, duration, parallelism, and delay (sleep) between the two benchmark executions.  
- The operations are performed sequentially as detailed below:
   ~~~
   [1/8] Creating namespace 'warp-benchmark'...
   [2/8] Creating ObjectBucketClaim...
   [3/8] Waiting for OBC to be bound (provisioning bucket)...
   [4/8] Extracting credentials...
   [5/8] Deploying Warp Runner Pod...
   [6/8] Running PUT Benchmark...
   [7/8] Sleeping for 2m before GET benchmark...
   [8/8] Running GET Benchmark...
   ~~~
   
## Variables customizable in the run-warp-benchmark-v4.sh script.
The warp-benchmark scripts support the customization of the following Variables: 

       # Configuration:
       NAMESPACE="warp-benchmark"
       STORAGE_CLASS="openshift-storage.noobaa.io"
       WARP_IMAGE="quay.io/minio/warp:latest"
       LOG_PREFIX="custom-run"
       CLEAN_OBC_TIMEOUT="240s"   # Timeout for OBC deletion
       POD_ODB_PAUSE=30           # Sleep applied to ODB post deletion and POD post creation

       # Warp Benchmark Settings:
       WARP_CONCURRENT="7"
       # WARP_CONCURRENT=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.spec.multiCloudGateway.endpoints.maxCount}{"\n"}')
       WARP_OBJ_SIZE="1536KiB"    # Object size
       WARP_GET_OBJECTS=100       # Number of objects pre-allocated to supporte for GET/GET MIXED benchmarks
       BENCHMARK_PAUSE="10"       # Time to sleep between benchmarks (Integer)

       # Durations:
       WARP_DURATION_PUT="10m"    # Duration for PUT benchmark (seconds or minutes: e.g.: 30s, 60s, 10m ..)
       WARP_DURATION_GET="10m"    # Duration for GET benchmark (seconds or minutes: e.g.: 30s, 60s, 10m ..)
       WARP_DURATION_MIXED="10m"  # Duration for MIXED benchmark (seconds or minutes: e.g.: 30s, 60s, 10m ..)

       # Mixed Ration:
       # Note: The amount of DELETE operations. Must be same or lower than WARP_MIXED_PUT_RATIO
       WARP_MIXED_GET_RATIO=50        # Mixed Ratio: % of operations that are GETs.
       WARP_MIXED_PUT_RATIO=50        # Mixed Ratio: % of operations that are GETs.
       WARP_MIXED_DELETE_RATIO=0      # Mixed Ratio: % of operations that are DELETEs. 
       WARP_MIXED_STAT_RATIO=0        # Mixed Ratio: % of operations that are STATs.

       # noobaa endopoint deduplication_disabled [true|false]
       DEDUPLICATION_DISABLE="true"
       SEARCH_TERM="CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP"
       CHECK_INTERVAL=10              # seconds

       ~~~
       
## Output details:
- The output includes throughput measured in MB/s showing data transfer rates. 
- Operations per second display how many GET / PUT requests the system can handle. 
- Latency percentiles show response times at p50, p90, p99, and p99.9 levels for operations.
- TTFB is the time from request was sent to the first byte was received.
- During the mixed operations phase, the command executes operations according to the configured distribution.
- The mixed benchmark randomly selects operation types based on the distribution percentages.

## Usefull links:
- [MinIO warp](https://docs.min.io/enterprise/minio-warp).
- [Throughput](https://docs.min.io/enterprise/minio-warp/reference/#throughput).
- [Operations per second](https://docs.min.io/enterprise/minio-warp/reference/#operations-per-second).
- [Latency percentiles](https://docs.min.io/enterprise/minio-warp/reference/#latency-metrics).

## Example of the output generated by "warp-benchmark-v5.sh all"
~~~
[root@dr-ocp-bastion-server ~]# ./warp-benchmark-v5.sh all
#------ Executing Workload: all - 2026-01-31 16:53:54 -------#
[1/15] Ratio check
[2/15] Setting noobaa deduplication_disable to true
deployment.apps/noobaa-endpoint updated
Waiting for all endpoints to update to value '0'...
--- Waiting for pods to scale... (Found 11, Expected 8) ---
--- Waiting for pods to scale... (Found 11, Expected 8) ---
--- Waiting for pods to scale... (Found 14, Expected 8) ---
--- Waiting for pods to scale... (Found 12, Expected 8) ---
--- Waiting for pods to scale... (Found 12, Expected 8) ---
--- Waiting for pods to scale... (Found 11, Expected 8) ---
--- Waiting for pods to scale... (Found 11, Expected 8) ---
--- Waiting for pods to scale... (Found 11, Expected 8) ---
--- Waiting for pods to scale... (Found 9, Expected 8) ---
SUCCESS - All 8 endpoints are now set to 0.
# noobaa-endpoint-5ddffbc594-62nq9
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-5ddffbc594-mnv5b
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-5ddffbc594-r2bhf
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-5ddffbc594-rqkr6
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-5ddffbc594-srmdv
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-5ddffbc594-tskw5
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-5ddffbc594-vrrpr
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-5ddffbc594-zl52q
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
[3/15] Warp General Settings:
StorageClass: openshift-storage.noobaa.io - Concurrent: 8 - Size: 1536KiB
Noobaa Deduplication: true - Noobaa Endpoints: 8
PUT Duration: 15s - GET Duration: 15s - MIXED Duration: 15s
MIXED Ratio: 50% GETs - 50% PUTs - 0% DELETEs - 0% STATs
# Start GET and PUT benchmarks
[4/15] Creating namespace 'warp-benchmark'...
Namespace 'warp-benchmark' already exists. Switching context...
[5/15] Deleting and re-creating ObjectBucketClaim ...
No old ObjectBucketClaims found.
objectbucketclaim.objectbucket.io/warp-benchmark-bucket-6wpt created
[6/15] Waiting for OBC to be bound (provisioning bucket)...
Waiting for bucket provisioning...
OBC is Bound.
[7/15] Extracting credentials...
Endpoint: s3.openshift-storage.svc
Bucket:   warp-bucket-ec9f3b14-ade2-4eab-96b8-86d71ce1d6ee
[8/15] Clenup old Warp Running Pod
[9/15] Deploying Warp Runner Pod...
pod/warp-runner created
Waiting for Pod to be Ready...
pod/warp-runner condition met
..............................
[10/15] Running GET Benchmark...
---------------------------------------------------
>>> Starting GET Benchmark (15s)...
    Saving to: /tmp/custom-run-get-20260131-215618.json.zst
>>> Analyzing GET Results:


Report: GET (677 reqs). Ran Duration: 13s, starting 21:56:33 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 8.
 * Average: 67.72 MiB/s, 45.15 obj/s (13s)
 * Reqs: Avg: 182.3ms, 50%: 174.9ms, 90%: 313.3ms, 99%: 482.3ms, Fastest: 36.6ms, Slowest: 613.5ms, StdDev: 93.6ms
 * TTFB: Avg: 165ms, Best: 28ms, 25th: 91ms, Median: 156ms, 75th: 192ms, 90th: 293ms, 99th: 468ms, Worst: 606ms StdDev: 93ms

Throughput, split into 13 x 1s:
 * Fastest: 87.8MiB/s, 58.54 obj/s (1s, starting 21:56:37 UTC)
 * 50% Median: 67.0MiB/s, 44.68 obj/s (1s, starting 21:56:40 UTC)
 * Slowest: 47.1MiB/s, 31.42 obj/s (1s, starting 21:56:41 UTC)


---------------------------------------------------
[11/15] Sleeping for 30 before PUT benchmark...
..............................Resuming...
---------------------------------------------------
[12/15] Running PUT Benchmark...
---------------------------------------------------
>>> Starting PUT Benchmark (15s)...
    Saving to: /tmp/custom-run-put-20260131-215721.json.zst
>>> Analyzing PUT Results:


Report: PUT (350 reqs). Ran Duration: 13s, starting 21:57:27 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 8.
 * Average: 36.60 MiB/s, 24.40 obj/s (13s)
 * Reqs: Avg: 337.6ms, 50%: 273.2ms, 90%: 509.6ms, 99%: 1558.0ms, Fastest: 138.7ms, Slowest: 2774.1ms, StdDev: 249.7ms

Throughput, split into 13 x 1s:
 * Fastest: 49.4MiB/s, 32.96 obj/s (1s, starting 21:57:34 UTC)
 * 50% Median: 38.5MiB/s, 25.68 obj/s (1s, starting 21:57:36 UTC)
 * Slowest: 7.3MiB/s, 4.84 obj/s (1s, starting 21:57:25 UTC)


# Start MIXED benchmarks
[4/15] Creating namespace 'warp-benchmark'...
Namespace 'warp-benchmark' already exists. Switching context...
[5/15] Deleting and re-creating ObjectBucketClaim warp-benchmark-bucket-6wpt...
Deleting found OBCs...
objectbucketclaim.objectbucket.io "warp-benchmark-bucket-6wpt" deleted
objectbucketclaim.objectbucket.io/warp-benchmark-bucket-1wrh created
[6/15] Waiting for OBC to be bound (provisioning bucket)...
Waiting for bucket provisioning...
OBC is Bound.
[7/15] Extracting credentials...
Endpoint: s3.openshift-storage.svc
Bucket:   warp-bucket-067f2974-cb72-4f3a-bded-18a49188c464
[8/15] Clenup old Warp Running Pod
Deleting old 'warp-runner' pod...
Old pod removed.
[9/15] Deploying Warp Runner Pod...
pod/warp-runner created
Waiting for Pod to be Ready...
pod/warp-runner condition met
..............................
[13/15] Running MIXED Benchmark...
---------------------------------------------------
>>> Starting MIXED Benchmark (15s)...
    Ratio: 50% GETs + 50% PUTs + 0% DELETEs + 0% STATs 
    Saving to: /tmp/custom-run-mixed-20260131-215904.json.zst
>>> Analyzing MIXED Results:


Report: GET (262 reqs). Ran Duration: 12s, starting 21:59:15 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 8.
 * Average: 25.49 MiB/s, 17.00 obj/s (12s)
 * Reqs: Avg: 157.7ms, 50%: 135.8ms, 90%: 298.9ms, 99%: 487.1ms, Fastest: 24.2ms, Slowest: 605.8ms, StdDev: 96.1ms
 * TTFB: Avg: 142ms, Best: 19ms, 25th: 75ms, Median: 127ms, 75th: 175ms, 90th: 278ms, 99th: 469ms, Worst: 581ms StdDev: 92ms

Throughput, split into 12 x 1s:
 * Fastest: 41.1MiB/s, 27.37 obj/s (1s, starting 21:59:23 UTC)
 * 50% Median: 26.0MiB/s, 17.36 obj/s (1s, starting 21:59:19 UTC)
 * Slowest: 15.1MiB/s, 10.07 obj/s (1s, starting 21:59:13 UTC)

──────────────────────────────────

Report: PUT (263 reqs). Ran Duration: 12s, starting 21:59:15 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 8.
 * Average: 26.84 MiB/s, 17.89 obj/s (12s)
 * Reqs: Avg: 296.0ms, 50%: 255.2ms, 90%: 494.4ms, 99%: 724.2ms, Fastest: 121.7ms, Slowest: 790.1ms, StdDev: 134.3ms

Throughput, split into 12 x 1s:
 * Fastest: 36.3MiB/s, 24.21 obj/s (1s, starting 21:59:24 UTC)
 * 50% Median: 26.7MiB/s, 17.79 obj/s (1s, starting 21:59:17 UTC)
 * Slowest: 19.4MiB/s, 12.96 obj/s (1s, starting 21:59:16 UTC)


──────────────────────────────────

Report: Total (525 reqs). Ran Duration: 12s, starting 21:59:15 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 8.
 * Average: 52.34 MiB/s, 34.89 obj/s (12s)

Throughput, split into 12 x 1s:
 * Fastest: 71.5MiB/s, 47.65 obj/s (1s, starting 21:59:24 UTC)
 * 50% Median: 52.9MiB/s, 35.27 obj/s (1s, starting 21:59:19 UTC)
 * Slowest: 40.7MiB/s, 27.16 obj/s (1s, starting 21:59:15 UTC)

[14/15] Cleanup phase.
Deleting OBC: warp-benchmark-bucket-1wrh...
objectbucketclaim.objectbucket.io "warp-benchmark-bucket-1wrh" deleted
Deleting pod warp-runner...
pod "warp-runner" deleted
Enabling noobaa deduplication...
deployment.apps/noobaa-endpoint updated
Waiting for all endpoints to clear the environment variable...
--- Waiting for pods to scale... (Found 9, Expected 8) ---
--- Waiting for pods to scale... (Found 11, Expected 8) ---
--- Waiting for pods to scale... (Found 14, Expected 8) ---
--- Waiting for pods to scale... (Found 14, Expected 8) ---
--- Waiting for pods to scale... (Found 12, Expected 8) ---
--- Waiting for pods to scale... (Found 11, Expected 8) ---
--- Waiting for pods to scale... (Found 11, Expected 8) ---
--- Waiting for pods to scale... (Found 11, Expected 8) ---
--- Waiting for pods to scale... (Found 9, Expected 8) ---
SUCCESS - Variable 'CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP' has been removed from all 8 pods.
---------------------------------------------------
[15/15] Benchmarks Complete.
---------------------------------------------------

-------------------- NOTES ------------------------
---------------------------------------------------
The output includes throughput measured in MB/s showing data transfer rates.
Operations per second display how many GET / PUT requests the system can handle.
Latency percentiles show response times at p50, p90, p99, and p99.9 levels for operations.
Links:
Throughput -> https://docs.min.io/enterprise/minio-warp/reference/#throughput
Operations per second -> https://docs.min.io/enterprise/minio-warp/reference/#operations-per-second
Latency percentiles -> https://docs.min.io/enterprise/minio-warp/reference/#latency-metrics
~~~
