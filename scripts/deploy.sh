#!/usr/bin/env bash
set -euo pipefail

APP_NAME="webapp"
APP_ROOT="/opt/webapp"
RELEASES_DIR="${APP_ROOT}/releases"
CURRENT_LINK="${APP_ROOT}/current"
SERVICE_FILE="/etc/systemd/system/webapp.service"

SHA="${1:?Commit SHA is required}"
ARTIFACT="${2:?Artifact path is required}"

RELEASE_DIR="${RELEASES_DIR}/${SHA}"

echo "Deploying ${APP_NAME} release ${SHA}"

echo "Creating release directory..."
sudo mkdir -p "${RELEASE_DIR}"

echo "Extracting artifact..."
sudo tar -xzf "${ARTIFACT}" -C "${RELEASE_DIR}"

echo "Installing systemd service..."
sudo cp "${RELEASE_DIR}/deploy/webapp.service" "${SERVICE_FILE}"
sudo systemctl daemon-reload
sudo systemctl enable webapp

echo "Updating current symlink..."
sudo ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}"

echo "Restarting application..."
sudo systemctl restart webapp

echo "Waiting for health check..."

for _ in {1..30}; do
    if curl -fsS http://localhost:3000/health >/dev/null; then
        echo "Health check passed."
        exit 0
    fi

    sleep 1
done

echo "Health check failed."

echo "Rolling back..."

PREVIOUS_RELEASE=$(find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d ! -name "${SHA}" | sort | tail -n 1 || true)

if [[ -n "${PREVIOUS_RELEASE}" ]]; then
    sudo ln -sfn "${PREVIOUS_RELEASE}" "${CURRENT_LINK}"
    sudo systemctl restart webapp
    echo "Rolled back to ${PREVIOUS_RELEASE}"
else
    echo "No previous release available for rollback."
fi

exit 1