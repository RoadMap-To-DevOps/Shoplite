#!/usr/bin/env bash

set -euo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------

APP_ROOT="/opt/webapp"
RELEASES_DIR="${APP_ROOT}/releases"
CURRENT_LINK="${APP_ROOT}/current"

SERVICE_FILE="/etc/systemd/system/webapp.service"

SOURCE_DIR="/tmp/webapp-deploy"

SHA="${1:?Usage: deploy.sh <commit-sha>}"
RELEASE_DIR="${RELEASES_DIR}/${SHA}"

# --------------------------------------------------
# Functions
# --------------------------------------------------

health_check() {
    curl -fsS http://localhost:3000/health >/dev/null 2>&1
}

rollback() {
    echo "Health check failed."
    echo "Starting rollback..."

    PREVIOUS_RELEASE="$(
        find "${RELEASES_DIR}" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            ! -name "${SHA}" \
            -printf '%T@ %p\n' |
        sort -nr |
        head -n 1 |
        cut -d' ' -f2-
    )"

    if [[ -n "${PREVIOUS_RELEASE}" ]]; then
        echo "Rolling back to:"
        echo "${PREVIOUS_RELEASE}"

        sudo ln -sfn "${PREVIOUS_RELEASE}" "${CURRENT_LINK}"

        sudo systemctl restart webapp

        echo "Rollback completed."
    else
        echo "No previous release available for rollback."
    fi
}

# --------------------------------------------------
# Deployment
# --------------------------------------------------

echo "========================================"
echo "Shoplite Deployment"
echo "Release: ${SHA}"
echo "========================================"

echo "Creating release directory..."

sudo mkdir -p "${RELEASE_DIR}"

echo "Copying application files..."

sudo cp -a "${SOURCE_DIR}/app/." "${RELEASE_DIR}/"

echo "Installing systemd service..."

sudo cp \
    "${SOURCE_DIR}/deploy/webapp.service" \
    "${SERVICE_FILE}"

sudo systemctl daemon-reload

sudo systemctl enable webapp

echo "Updating current symlink..."

sudo ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}"

echo "Restarting webapp service..."

sudo systemctl restart webapp

echo "Waiting for application health..."

for _ in {1..30}; do

    if health_check; then
        echo "Health check passed."
        echo "Release ${SHA} deployed successfully."

        sudo rm -rf "${SOURCE_DIR}"

        exit 0
    fi

    sleep 1
done

# --------------------------------------------------
# Rollback
# --------------------------------------------------

rollback

sudo rm -rf "${SOURCE_DIR}"

exit 1