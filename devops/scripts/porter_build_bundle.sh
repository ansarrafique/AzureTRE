#!/bin/bash
set -euo pipefail

# Initialize variables
CACHE_FLAGS=()
BUILDER_NAME="tre-builder"
LOG_FILE=$(mktemp)

# 1. Source context if available (Standard AzureTRE logic)
if [ -f "porter-build-context.env" ]; then
    # shellcheck disable=SC1091
    source "porter-build-context.env"
    echo "Found additional porter build context PORTER_BUILD_CONTEXT of ${PORTER_BUILD_CONTEXT:-}"
    porter build --build-context "${PORTER_BUILD_CONTEXT:-}"
    exit 0
fi

# 2. Check for Docker, Buildx, and Caching support
if command -v docker >/dev/null 2>&1 && \
   docker buildx version >/dev/null 2>&1 && \
   [ -n "${CI_CACHE_ACR_FQDN:-}" ] && \
   command -v yq >/dev/null 2>&1; then
    
    # Try to ensure the builder exists
    if docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1 || \
       docker buildx create --name "$BUILDER_NAME" --driver docker-container --use >/dev/null 2>&1; then
        
        docker buildx use "$BUILDER_NAME" >/dev/null 2>&1 || true
        
        # Sanitizing bundle name (removing quotes from yq output)
        BUNDLE_NAME=$(yq '.name' porter.yaml 2>/dev/null | tr -d '"')
        if [ -z "$BUNDLE_NAME" ]; then BUNDLE_NAME="bundle"; fi
        
        REF="${CI_CACHE_ACR_FQDN}/build-cache/${BUNDLE_NAME}:porter"
        
        # Define Cache Flags
        # Note: We add --build-arg BASE_IMAGE to solve the 'base:latest' pull error
        # In AzureTRE, the base image is usually tre-base in your ACR.
        CACHE_FLAGS=(
            --cache-to "type=inline"
            --cache-from "type=registry,ref=${REF}"
            --build-arg "BASE_IMAGE=${CI_CACHE_ACR_FQDN}/base/tre-base:latest"
        )
    fi
fi

# 3. Execution with specific error handling
echo "Building bundle in $PWD..."

# We use 'set +e' to handle the fallback logic manually
set +e
# Use PIPESTATUS to catch porter's exit code, not tee's
porter build "${CACHE_FLAGS[@]}" 2>&1 | tee "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ $EXIT_CODE -ne 0 ]; then
    # Check if the failure was specifically due to unsupported flags
    if grep -iq "unknown flag: --cache-to" "$LOG_FILE"; then
        echo "Detected unsupported cache flags. Retrying clean build..."
        # We still include the BASE_IMAGE build arg even in fallback to ensure the Dockerfile builds
        porter build --build-arg "BASE_IMAGE=${CI_CACHE_ACR_FQDN:-}/base/tre-base:latest"
    else
        echo "Build failed due to a legitimate error (e.g., Docker pull access denied)."
        rm -f "$LOG_FILE"
        exit $EXIT_CODE
    fi
fi

# Cleanup
rm -f "$LOG_FILE"