
# Warp Benchmark Script.

## General Notes:
   - The latest version of the script is warp-benchmark-v5.sh.
   - Benchmark tests were conducted in a test environment configured to align with OCP 4.16 and ODF 4.20.

## Notes warp-benchmark-V5.sh (LATEST version):
- warp image defined/assigned via WARP_IMAGE variable.
- Disable the option to exclude relatively new chunks from deduplication (SKIP_NEW_CHANKS variable).  
  Setting it to 0 ensures all new chunks are considered for deduplication, whereas the default considers only chunks that are 1 hour old.
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
#------ Executing Workload: standard - 2026-02-03 04:13:25 -------#
[1/15] Ratio check
[2/15] Setting noobaa Not Skip New Chunks for Deduplication to true
deployment.apps/noobaa-endpoint updated
Waiting for all endpoints to update to value '0'...
--- Waiting for pods to scale... (Found 9, Expected 7) ---
--- Waiting for pods to scale... (Found 9, Expected 7) ---
--- Waiting for pods to scale... (Found 11, Expected 7) ---
--- Waiting for pods to scale... (Found 12, Expected 7) ---
--- Waiting for pods to scale... (Found 12, Expected 7) ---
--- Waiting for pods to scale... (Found 11, Expected 7) ---
--- Waiting for pods to scale... (Found 9, Expected 7) ---
SUCCESS - All 7 endpoints are now set to 0.
# noobaa-endpoint-776bdc7bb8-55v2l
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-776bdc7bb8-dnm5z
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-776bdc7bb8-h7k2d
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-776bdc7bb8-nmrmn
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-776bdc7bb8-tdgm5
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-776bdc7bb8-vbtfk
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
# noobaa-endpoint-776bdc7bb8-wtzbn
    - name: CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP
      value: "0"
[3/15] Warp General Settings:
StorageClass: openshift-storage.noobaa.io - Concurrent: 7 - Size: 1536KiB
Noobaa Not Skip chunks for Deduplication: true - Noobaa Endpoints: 7
PUT Duration: 15s - GET Duration: 15s - MIXED Duration: 15s
MIXED Ratio: 50% GETs - 50% PUTs - 0% DELETEs - 0% STATs
# Start GET and PUT benchmarks
[4/15] Creating namespace 'warp-benchmark'...
Namespace 'warp-benchmark' already exists. Switching context...
[5/15] Deleting and re-creating ObjectBucketClaim ...
No old ObjectBucketClaims found.
objectbucketclaim.objectbucket.io/warp-benchmark-bucket-xk58 created
[6/15] Waiting for OBC to be bound (provisioning bucket)...
Waiting for bucket provisioning...
OBC is Bound.
[7/15] Extracting credentials...
Endpoint: s3.openshift-storage.svc
Bucket:   warp-bucket-5d856be1-9066-447f-be0f-20dac912402d
[8/15] Clenup old Warp Running Pod
[9/15] Deploying Warp Runner Pod...
pod/warp-runner created
Waiting for Pod to be Ready...
pod/warp-runner condition met
..............................
[10/15] Running GET Benchmark...
---------------------------------------------------
>>> Starting GET Benchmark (15s)...
    Saving to: /tmp/custom-run-get-20260203-121611.json.zst
>>> Analyzing GET Results:


Report: GET (1815 reqs). Ran Duration: 12s, starting 12:16:20 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 7.
 * Average: 181.90 MiB/s, 121.27 obj/s (12s)
 * Reqs: Avg: 57.0ms, 50%: 59.2ms, 90%: 88.9ms, 99%: 199.5ms, Fastest: 14.5ms, Slowest: 1210.7ms, StdDev: 51.8ms
 * TTFB: Avg: 51ms, Best: 12ms, 25th: 19ms, Median: 55ms, 75th: 72ms, 90th: 83ms, 99th: 193ms, Worst: 1.206s StdDev: 51ms

Throughput, split into 12 x 1s:
 * Fastest: 220.6MiB/s, 147.10 obj/s (1s, starting 12:16:25 UTC)
 * 50% Median: 207.1MiB/s, 138.03 obj/s (1s, starting 12:16:26 UTC)
 * Slowest: 53.4MiB/s, 35.61 obj/s (1s, starting 12:16:19 UTC)


---------------------------------------------------
[11/15] Sleeping for 30 before PUT benchmark...
..............................Resuming...
---------------------------------------------------
[12/15] Running PUT Benchmark...
---------------------------------------------------
>>> Starting PUT Benchmark (15s)...
    Saving to: /tmp/custom-run-put-20260203-121705.json.zst
>>> Analyzing PUT Results:


Report: PUT (1020 reqs). Ran Duration: 12s, starting 12:17:10 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 7.
 * Average: 105.91 MiB/s, 70.60 obj/s (12s)
 * Reqs: Avg: 100.8ms, 50%: 65.2ms, 90%: 188.6ms, 99%: 528.6ms, Fastest: 41.8ms, Slowest: 1168.0ms, StdDev: 87.1ms

Throughput, split into 12 x 1s:
 * Fastest: 136.7MiB/s, 91.12 obj/s (1s, starting 12:17:08 UTC)
 * 50% Median: 114.5MiB/s, 76.31 obj/s (1s, starting 12:17:19 UTC)
 * Slowest: 22.9MiB/s, 15.25 obj/s (1s, starting 12:17:13 UTC)


[14/15] Cleanup phase.
Deleting OBC: warp-benchmark-bucket-xk58...
objectbucketclaim.objectbucket.io "warp-benchmark-bucket-xk58" deleted
Deleting pod warp-runner...
pod "warp-runner" deleted
Enabling noobaa Skip New Chunks ...
deployment.apps/noobaa-endpoint updated
Waiting for all endpoints to clear the environment variable...
--- Waiting for pods to scale... (Found 9, Expected 7) ---
--- Waiting for pods to scale... (Found 9, Expected 7) ---
--- Waiting for pods to scale... (Found 11, Expected 7) ---
--- Waiting for pods to scale... (Found 13, Expected 7) ---
--- Waiting for pods to scale... (Found 12, Expected 7) ---
--- Waiting for pods to scale... (Found 11, Expected 7) ---
--- Waiting for pods to scale... (Found 9, Expected 7) ---
SUCCESS - Variable 'CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP' has been removed from all 7 pods.
---------------------------------------------------
[15/15] Benchmarks Completed.
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
