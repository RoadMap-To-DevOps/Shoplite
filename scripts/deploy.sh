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
        echo "No previous release available."
    fi
}

# --------------------------------------------------
# Deployment
# --------------------------------------------------

echo "========================================"
echo "Shoplite Deployment"
echo "Release: ${SHA}"
echo "========================================"

# --------------------------------------------------
# Ensure webapp user exists
# --------------------------------------------------

echo "Ensuring webapp user exists..."

if ! id webapp >/dev/null 2>&1; then
    echo "Creating webapp user..."

    sudo useradd \
        --system \
        --create-home \
        --shell /sbin/nologin \
        webapp
else
    echo "webapp user already exists."
fi

# --------------------------------------------------
# Prepare application directory
# --------------------------------------------------

echo "Preparing application directory..."

sudo mkdir -p "${APP_ROOT}"
sudo mkdir -p "${RELEASES_DIR}"

sudo chown -R webapp:webapp "${APP_ROOT}"

# --------------------------------------------------
# Create release
# --------------------------------------------------

echo "Creating release directory..."

sudo mkdir -p "${RELEASE_DIR}"

echo "Copying application files..."

sudo cp -a "${SOURCE_DIR}/app/." "${RELEASE_DIR}/"

sudo chown -R webapp:webapp "${RELEASE_DIR}"

# --------------------------------------------------
# Install systemd service
# --------------------------------------------------

echo "Installing systemd service..."

sudo cp \
    "${SOURCE_DIR}/deploy/webapp.service" \
    "${SERVICE_FILE}"

sudo systemctl daemon-reload

sudo systemctl enable webapp

# --------------------------------------------------
# Activate release
# --------------------------------------------------

echo "Updating current symlink..."

sudo ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}"

# --------------------------------------------------
# Restart application
# --------------------------------------------------

echo "Restarting webapp service..."

sudo systemctl restart webapp

# --------------------------------------------------
# Health check
# --------------------------------------------------

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