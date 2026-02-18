#!/bin/bash
set -euo pipefail

# Initialize variables
CACHE_FLAGS=()

# ... (keep the same source porter-build-context.env logic) ...

if [ -n "${CI_CACHE_ACR_FQDN:-}" ] && command -v yq >/dev/null 2>&1; then
    # Try to set up the builder
    if docker buildx inspect tre-builder >/dev/null 2>&1 || \
       docker buildx create --name tre-builder --driver docker-container --use >/dev/null 2>&1; then
        
        docker buildx use tre-builder
        
        # Safely get bundle name
        BUNDLE_NAME=$(yq '.name' porter.yaml 2>/dev/null || echo "bundle")
        REF="${CI_CACHE_ACR_FQDN}/build-cache/${BUNDLE_NAME}:porter"
        
        # We define them, but we will wrap the execution in a check
        CACHE_FLAGS=(--cache-to "type=inline" --cache-from "type=registry,ref=${REF}")
    fi
fi

# THE CORE FIX: Catch the 'unknown flag' error specifically
echo "Building bundle in $PWD..."
if [ ${#CACHE_FLAGS[@]} -gt 0 ]; then
    # Try with flags, if it fails with exit code 1 (usually flag errors), fallback
    set +e
    porter build "${CACHE_FLAGS[@]}"
    exit_code=$?
    set -e

    if [ $exit_code -ne 0 ]; then
        echo "Build failed with cache flags (exit $exit_code). Retrying without cache..."
        porter build
    fi
else
    porter build
fi