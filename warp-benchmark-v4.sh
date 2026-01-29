##################################################################
#                                                                #
#      run-warp-benchmark-v4.sh - version 4.0 - Jan 29, 2026     #
#                                                                #
#       - New version with GET, PUT and MIXED benchmarks         # 
#       - Image changed to: quay.io/minio/warp:latest            #
#       - StorageClass name added to the sript output            #
#       - noobaa deduplication disable                           #
#                                                                #
#  Usage: ./warp-benchmark-v4.sh [mixed|standard|get|put|all]    #
#                                                                #
###################### rbruzzon@redhat.com #######################

#!/bin/bash
set -e

# Configuration
NAMESPACE="warp-benchmark"
STORAGE_CLASS="openshift-storage.noobaa.io" # Use "openshift-storage.noobaa.io" or "ocs-storagecluster-ceph-rgw"
LOG_PREFIX="custom-run"
CLEAN_OBC_TIMEOUT="240s"   # Timeout for OBC deletion
POD_ODB_PAUSE=30           # Sleep applied to ODB post deletion and POD post creation

# Warp Benchmark Settings
WARP_CONCURRENT=$(oc get pods -n openshift-storage | grep endpoint | wc -l)   # Number of concurrent operations
WARP_OBJ_SIZE="1536KiB"    # Object size
WARP_GET_OBJECTS="100"     # Number of objects created in the S3 to support GET and MIXED (GET) benchmarks
BENCHMARK_PAUSE="60"        # sleep between GET and PUT benchmarks (Integer)

# Durations
WARP_DURATION_PUT="10m"    # Duration for PUT benchmark
WARP_DURATION_GET="10m"    # Duration for GET benchmark
WARP_DURATION_MIXED="10m"  # Duration for MIXED benchmark

# Mixed Ration (50 means 50%)
# Note: The amount of DELETE operations. Must be same or lower than WARP_MIXED_PUT_RATIO
WARP_MIXED_GET_RATIO=50        # Mixed Ratio: % of operations that are GETs.
WARP_MIXED_PUT_RATIO=50        # Mixed Ratio: % of operations that are PUT.
WARP_MIXED_DELETE_RATIO=0      # Mixed Ratio: % of operations that are DELETEs.
WARP_MIXED_STAT_RATIO=0        # Mixed Ratio: % of operations that are STATs.

# noobaa endopoint deduplication_disabled [true|false]
DEDUPLICATION_DISABLE=true
SEARCH_TERM="CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP"
CHECK_INTERVAL=10              # seconds

ratio_check () {

    echo "[1/15] Ratio check"
    if [ $((WARP_MIXED_GET_RATIO + WARP_MIXED_PUT_RATIO + WARP_MIXED_DELETE_RATIO + WARP_MIXED_STAT_RATIO)) -ne 100 ]; then
        echo "Error: The sum of ratios (GET, PUT, DELETE and STAT) is $((WARP_MIXED_GET_RATIO + WARP_MIXED_PUT_RATIO + WARP_MIXED_DELETE_RATIO + WARP_MIXED_STAT_RATIO ))."
        echo "They must sum up to exactly 100."
        exit 1
    fi
    if [ "$WARP_MIXED_DELETE_RATIO" -gt "$WARP_MIXED_PUT_RATIO" ]; then
        echo "Error: DELETE ratio ($WARP_MIXED_DELETE_RATIO) cannot be higher than PUT ratio ($WARP_MIXED_PUT_RATIO)."
        exit 2
    fi

}

start_benchmark () {

    echo "[3/15] Warp General Settings:"
    echo "StorageClass=$STORAGE_CLASS - Concurrent=$WARP_CONCURRENT - Size=$WARP_OBJ_SIZE" - noobaa Deduplication Disabled=$DEDUPLICATION_DISABLE
    echo "PUT Duration: $WARP_DURATION_PUT - GET Duration: $WARP_DURATION_GET - MIXED Duration: $WARP_DURATION_MIXED"
    echo "MIXED Ratio: $WARP_MIXED_GET_RATIO% GETs - $WARP_MIXED_PUT_RATIO% PUTs - $WARP_MIXED_DELETE_RATIO% DELETEs - $WARP_MIXED_STAT_RATIO% STATs"

}

deduplication_disabled () {

if [ "$STORAGE_CLASS" = "openshift-storage.noobaa.io" ] && [ "$DEDUPLICATION_DISABLE" = "true" ]; then
    echo "[2/15] Disable noobaa deduplication"
    
    # Trigger the update
    oc set env deployment/noobaa-endpoint "$SEARCH_TERM=0" -n openshift-storage

    echo "Waiting for all endpoints to update to value '0'..."

    while true; do

        POD_LIST=$(oc get pods -n openshift-storage --no-headers | grep endpoint | awk '{print $1}')
        ACTUAL_COUNT=$(echo "$POD_LIST" | wc -w)
        
        # Verify if the count matches your expected WARP_CONCURRENT
        if [ "$ACTUAL_COUNT" -ne "${WARP_CONCURRENT:-0}" ]; then
            echo "--- Waiting for pods to scale... (Found $ACTUAL_COUNT, Expected $WARP_CONCURRENT) ---"
            sleep "$CHECK_INTERVAL"
            continue
        fi

        MATCH_COUNT=0

        for pod in $POD_LIST; do
            # Using jsonpath for a cleaner and more reliable value extraction
            VALUE=$(oc get pod "$pod" -n openshift-storage -o jsonpath='{.spec.containers[*].env[?(@.name=="'$SEARCH_TERM'")].value}')
            
            if [ "$VALUE" = "0" ]; then
                MATCH_COUNT=$((MATCH_COUNT + 1))
            fi
        done

        if [ "$MATCH_COUNT" -eq "$ACTUAL_COUNT" ]; then
            echo "SUCCESS - All $MATCH_COUNT endpoints are now set to 0."
            break 
        else
            echo "Pending - Only $MATCH_COUNT/$ACTUAL_COUNT pods are updated. Retrying in ${CHECK_INTERVAL}s..."
            sleep "$CHECK_INTERVAL"
        fi
        
    done

else

  oc set env deployment/noobaa-endpoint "${SEARCH_TERM}-" -n openshift-storage
  sleep 120
    
fi


}

creation_phase () {

    # 1. Create Namespace
    echo "[4/15] Creating namespace '$NAMESPACE'..."
    if ! oc get project $NAMESPACE >/dev/null 2>&1; then
        oc new-project $NAMESPACE
    else
        echo "Namespace '$NAMESPACE' already exists. Switching to it."
        oc project $NAMESPACE
    fi
    
    # 2. Delete and Create ObjectBucketClaim (OBC)
    echo "[5/15] Deleting and re-creating ObjectBucketClaim $OBC_NAME..."

    OBC_TO_DELETE=$(oc get obc -o name -n openshift-storage | grep "warp-benchmark" || true)

    if [ -n "$OBC_TO_DELETE" ]; then
        echo "Deleting found OBCs..."
        echo "$OBC_TO_DELETE" | xargs -r oc delete -n openshift-storage
    else
        echo "No old ObjectBucketClaims found."
    fi

    OBD_POSTFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 4 | head -n 1)
    OBC_NAME="warp-benchmark-bucket-${OBD_POSTFIX}"
    export OBC_NAME

    cat <<EOF | oc apply -f -
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: $OBC_NAME
  namespace: openshift-storage
spec:
  generateBucketName: warp-bucket
  storageClassName: $STORAGE_CLASS
EOF
    
    # 3. Wait for OBC to be Bound
    echo "[6/15] Waiting for OBC to be bound (provisioning bucket)..."
    while [[ $(oc get obc $OBC_NAME -n openshift-storage -o jsonpath='{.status.phase}') != "Bound" ]]; do
        echo "Waiting for bucket provisioning..."
        sleep 5
    done
    echo "OBC is Bound."
    
    # 4. Extract Secrets
    echo "[7/15] Extracting credentials..."
    AWS_ACCESS_KEY_ID=$(oc get secret $OBC_NAME -n openshift-storage -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
    AWS_SECRET_ACCESS_KEY=$(oc get secret $OBC_NAME -n openshift-storage -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
    S3_ENDPOINT=$(oc get configmap $OBC_NAME -n openshift-storage -o jsonpath='{.data.BUCKET_HOST}')
    BUCKET_NAME=$(oc get configmap $OBC_NAME -n openshift-storage -o jsonpath='{.data.BUCKET_NAME}')
    
    echo "Endpoint: $S3_ENDPOINT"
    echo "Bucket:   $BUCKET_NAME"
    
    # 5. Delete old Warp Pod
    echo "[8/15] Clenup old Warp Running Pod"
    if oc get pod warp-runner -n $NAMESPACE > /dev/null 2>&1; then
        echo "Deleting old 'warp-runner' pod..."
        oc delete pod warp-runner -n $NAMESPACE > /dev/null 2>&1
        # We wait to ensure the name is free
        oc wait --for=delete pod/warp-runner -n $NAMESPACE --timeout=180s
        echo "Old pod removed."
    fi

    # 6. Create Warp Pod
    echo "[9/15] Deploying Warp Runner Pod..."
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: warp-runner
  namespace: $NAMESPACE
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: warp
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      runAsUser: 10001  # Force a random non-root ID to satisfy runAsNonRoot
    image: quay.io/minio/warp:latest
    command: ["/bin/sh", "-c", "sleep infinity"]
    env:
      - name: AWS_ACCESS_KEY_ID
        value: "$AWS_ACCESS_KEY_ID"
      - name: AWS_SECRET_ACCESS_KEY
        value: "$AWS_SECRET_ACCESS_KEY"
      - name: S3_ENDPOINT
        value: "$S3_ENDPOINT"
      - name: BUCKET_NAME
        value: "$BUCKET_NAME"
      - name: LOG_PREFIX
        value: "$LOG_PREFIX"
      - name: WARP_CONCURRENT
        value: "$WARP_CONCURRENT"
      - name: WARP_OBJ_SIZE
        value: "$WARP_OBJ_SIZE"
      - name: WARP_GET_OBJECTS
        value: "$WARP_GET_OBJECTS"
      - name: WARP_DURATION_PUT
        value: "$WARP_DURATION_PUT"
      - name: WARP_DURATION_GET
        value: "$WARP_DURATION_GET"
      - name: WARP_DURATION_MIXED
        value: "$WARP_DURATION_MIXED"
      - name: WARP_MIXED_GET_RATIO
        value: "$WARP_MIXED_GET_RATIO"
      - name: WARP_MIXED_PUT_RATIO
        value: "$WARP_MIXED_PUT_RATIO"
      - name: WARP_MIXED_DELETE_RATIO
        value: "$WARP_MIXED_DELETE_RATIO"
      - name: WARP_MIXED_STAT_RATIO
        value: "$WARP_MIXED_STAT_RATIO"
  restartPolicy: Never
EOF
    
    echo "Waiting for Pod to be Ready..."
    oc wait --for=condition=Ready pod/warp-runner -n $NAMESPACE --timeout=180s

    for ((i=1; i<=${POD_ODB_PAUSE}; i++)); do
        echo -n "."
        sleep 1
    done
    echo ""

}

run_get () {
    
    # 7. Run GET Benchmark
    echo "[10/15] Running GET Benchmark..."
    echo "---------------------------------------------------"
    PREFIX=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
    
    oc exec -n $NAMESPACE warp-runner -- /bin/sh -c '
        GET_FILE="/tmp/${LOG_PREFIX}-get-$(date +%Y%m%d-%H%M%S)"
        echo ">>> Starting GET Benchmark ($WARP_DURATION_GET)..."
        echo "    Saving to: ${GET_FILE}.json.zst"
    
        ./warp get \
          --host "$S3_ENDPOINT" \
          --access-key "$AWS_ACCESS_KEY_ID" \
          --secret-key "$AWS_SECRET_ACCESS_KEY" \
          --bucket "$BUCKET_NAME" \
          --prefix "warp-${PREFIX}-" \
          --concurrent "$WARP_CONCURRENT" \
          --objects "$WARP_GET_OBJECTS" \
          --obj.size "$WARP_OBJ_SIZE" \
          --duration "$WARP_DURATION_GET" \
          --insecure \
          --benchdata "$GET_FILE" > /dev/null
    
        echo ">>> Analyzing GET Results:"
        ./warp analyze --analyze.v "${GET_FILE}.json.zst"
    '
    
}

run_pause () {

    # 8. Pause 
    echo "---------------------------------------------------"
    echo "[11/15] Sleeping for $BENCHMARK_PAUSE before PUT benchmark..."
    for ((i=1; i<=${BENCHMARK_PAUSE}; i++)); do
        echo -n "."
        sleep 1
    done
    echo "Resuming..."
    echo "---------------------------------------------------"
    
}

run_put () {

    # 9. Run PUT Benchmark
    echo "[12/15] Running PUT Benchmark..."
    echo "---------------------------------------------------"
    PREFIX=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)

    oc exec -n $NAMESPACE warp-runner -- /bin/sh -c '
        PUT_FILE="/tmp/${LOG_PREFIX}-put-$(date +%Y%m%d-%H%M%S)"
        echo ">>> Starting PUT Benchmark ($WARP_DURATION_PUT)..."
        echo "    Saving to: ${PUT_FILE}.json.zst"
        
        ./warp put \
          --host "$S3_ENDPOINT" \
          --access-key "$AWS_ACCESS_KEY_ID" \
          --secret-key "$AWS_SECRET_ACCESS_KEY" \
          --bucket "$BUCKET_NAME" \
          --prefix "warp-${PREFIX}-" \
          --concurrent "$WARP_CONCURRENT" \
          --obj.size "$WARP_OBJ_SIZE" \
          --duration "$WARP_DURATION_PUT" \
          --insecure \
          --benchdata "$PUT_FILE" > /dev/null
    
        echo ">>> Analyzing PUT Results:"
        ./warp analyze --analyze.v "${PUT_FILE}.json.zst"
    '
}

run_mixed () {
    
    # 10. Pause 2
    # echo "---------------------------------------------------"
    # echo "[10/11] Sleeping for $BENCHMARK_PAUSE before MIXED benchmark..."
    # sleep $BENCHMARK_PAUSE
    # echo "Resuming..."
    # echo "---------------------------------------------------"
    
    # 11. Run MIXED Benchmark
    echo "[13/15] Running MIXED Benchmark..."
    echo "---------------------------------------------------"
    PREFIX=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
    
    oc exec -n $NAMESPACE warp-runner -- /bin/sh -c '
        MIXED_FILE="/tmp/${LOG_PREFIX}-mixed-$(date +%Y%m%d-%H%M%S)"
        echo ">>> Starting MIXED Benchmark ($WARP_DURATION_MIXED)..."
        echo "    Ratio: $WARP_MIXED_GET_RATIO% GETs + $WARP_MIXED_PUT_RATIO% PUTs + $WARP_MIXED_DELETE_RATIO% DELETEs + $WARP_MIXED_STAT_RATIO% STATs "
        echo "    Saving to: ${MIXED_FILE}.json.zst"
    
        ./warp mixed \
          --host "$S3_ENDPOINT" \
          --access-key "$AWS_ACCESS_KEY_ID" \
          --secret-key "$AWS_SECRET_ACCESS_KEY" \
          --bucket "$BUCKET_NAME" \
          --concurrent "$WARP_CONCURRENT" \
          --prefix "warp-${PREFIX}-" \
          --obj.size "$WARP_OBJ_SIZE" \
          --objects "$WARP_GET_OBJECTS" \
          --duration "$WARP_DURATION_MIXED" \
          --get-distrib "$WARP_MIXED_GET_RATIO" \
          --put-distrib "$WARP_MIXED_PUT_RATIO" \
          --delete-distrib "$WARP_MIXED_DELETE_RATIO" \
          --stat-distrib "$WARP_MIXED_STAT_RATIO" \
          --insecure \
          --benchdata "$MIXED_FILE" > /dev/null
    
        echo ">>> Analyzing MIXED Results:"
        ./warp analyze --analyze.v "${MIXED_FILE}.json.zst"
    '

}

benchmark_end () {
    
    echo "---------------------------------------------------"
    echo "[14/15] Benchmarks Complete."
    echo "---------------------------------------------------"
    echo ""
    echo "-------------------- NOTES ------------------------"
    echo "---------------------------------------------------"
    echo "The output includes throughput measured in MB/s showing data transfer rates."
    echo "Operations per second display how many GET / PUT requests the system can handle."
    echo "Latency percentiles show response times at p50, p90, p99, and p99.9 levels for operations."
    echo "Links:"
    echo "Throughput -> https://docs.min.io/enterprise/minio-warp/reference/#throughput"
    echo "Operations per second -> https://docs.min.io/enterprise/minio-warp/reference/#operations-per-second"
    echo "Latency percentiles -> https://docs.min.io/enterprise/minio-warp/reference/#latency-metrics"
    
}

cleanup_phase () {
    echo "[15/15] Cleanup phase."
    echo "Deleting OBC: $OBC_NAME..."
    oc delete obc $OBC_NAME -n openshift-storage
    oc delete pod warp-runner -n $NAMESPACE 
    oc set env deployment/noobaa-endpoint "${SEARCH_TERM}-" -n openshift-storage

}

#
# Main Function with Logic
#
main () {
    # 1. Read the argument (default to "mixed" if none provided)
    # WORKLOAD="${1:-standard}"
    WORKLOAD="$1"

    
    case "$WORKLOAD" in

        "mixed")
            # Runs only the mixed test
            echo "#------ Executing Workload: $WORKLOAD - $(date '+%Y-%m-%d %H:%M:%S') -------#"
            ratio_check        
            deduplication_disabled
            start_benchmark    # Print banner info
            creation_phase     # Setup Namespace/OBC/Pod
            run_mixed
            ;;
        
        "standard")
            # Runs GET and PUT tests
            echo "#------ Executing Workload: $WORKLOAD - $(date '+%Y-%m-%d %H:%M:%S') -------#"
            ratio_check        
            deduplication_disabled
            start_benchmark    # Print banner info
            echo "# Start GET and PUT benchmarks"
            creation_phase     # Setup Namespace/OBC/Pod
            run_get
	    run_pause
	    run_put
            ;;

        "get")
            # Runs GET test only
            echo "#------ Executing Workload: $WORKLOAD - $(date '+%Y-%m-%d %H:%M:%S') -------#"
            ratio_check        
            deduplication_disabled
            start_benchmark    # Print banner info
            echo "# Start GET only"
            creation_phase     # Setup Namespace/OBC/Pod
            run_get
            ;;

         "put")
            # Runs PUT test only
            echo "#------ Executing Workload: $WORKLOAD - $(date '+%Y-%m-%d %H:%M:%S') -------#"
            ratio_check        
            deduplication_disabled
            start_benchmark    # Print banner info
            echo "# Start PUT only"
            creation_phase     # Setup Namespace/OBC/Pod
            run_put
            ;;
 

        "all")
            # Runs EVERYTHING
            echo "#------ Executing Workload: $WORKLOAD - $(date '+%Y-%m-%d %H:%M:%S') -------#"
            ratio_check        
            deduplication_disabled
            start_benchmark    # Print banner info
            echo "# Start GET and PUT benchmarks"
            creation_phase     # Setup Namespace/OBC/Pod
            run_get
	    run_pause
            run_put
            echo "# Start MIXED benchmarks"
            creation_phase     # OBC/Pod recreated to remove dirty objects
            run_mixed
            ;;
        
        *)
            echo "Error: Invalid workload type '$WORKLOAD'"
            echo "Usage: $0 [mixed|standard|get|put|all]"
            exit 5
            ;;
    esac

    # 4. Finish
    cleanup_phase
    benchmark_end
    exit 6
}

# Execute Main and pass all arguments ("$@") to it
main "$@"
