#!/bin/bash

# 1. Strict Shell Options
set -euo pipefail

# 2. Initialize variables to avoid 'unbound variable' errors
BUILDER_NAME="tre-builder"
CACHE_FLAGS=()
BUILDER_SUPPORTED=false

# Check if yq is available (required for the cache ref)
if ! command -v yq >/dev/null 2>&1; then
    echo "Warning: 'yq' not found. Skipping caching logic."
    CI_CACHE_ACR_FQDN=""
fi

if [ -f "porter-build-context.env" ]; then
    source "porter-build-context.env"
    echo "Found additional porter build context PORTER_BUILD_CONTEXT of ${PORTER_BUILD_CONTEXT:-}"
    porter build --build-context "${PORTER_BUILD_CONTEXT:-}"
else
    # 3. Comprehensive Buildx & Cache-To Support Check
    if [ -n "${CI_CACHE_ACR_FQDN:-}" ]; then
        # Check if buildx plugin exists and if 'build' command supports --cache-to
        if docker buildx build --help 2>&1 | grep -q "\-\-cache-to"; then
            
            # 4. Attempt to setup/use the container driver
            if docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1 || \
               docker buildx create --name "$BUILDER_NAME" --driver docker-container --use >/dev/null 2>&1; then
                
                docker buildx use "$BUILDER_NAME"
                BUILDER_SUPPORTED=true
            fi
        fi

        if [ "$BUILDER_SUPPORTED" = true ]; then
            # Use a subshell for yq to safely capture the bundle name
            BUNDLE_NAME=$(yq '.name' porter.yaml 2>/dev/null || echo "unknown")
            REF="${CI_CACHE_ACR_FQDN}/build-cache/${BUNDLE_NAME}:porter"
            
            # 5. Use 'inline' for reliability, but keep registry-from for speed
            # Note: We don't fail the build if the registry is unreachable during cache-from
            CACHE_FLAGS=(--cache-to "type=inline" --cache-from "type=registry,ref=${REF}")
            echo "Buildx with --cache-to supported. Applying inline cache flags."
        else
            echo "Buildx or --cache-to not supported in this environment. Falling back to standard build."
        fi
    fi

    # 6. Execute Porter Build
    # If the registry is unreachable, Porter/BuildKit typically warns but continues 
    # unless the network error is fatal to the primary image push.
    porter build "${CACHE_FLAGS[@]}"
fi