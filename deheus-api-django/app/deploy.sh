#!/bin/bash
#
# Deploy script for Django API
# Run on server: bash deploy.sh
#
set -e

VENV=/home/devops/deheus-api-django/venv
APP_DIR=/home/devops/deheus-api-django/app
GIT_REPO=https://github.com/codingclubskenya/lcrm.git

echo "=== Pulling latest code ==="
cd $APP_DIR
git pull origin joe

echo "=== Installing dependencies ==="
$VENV/bin/pip install -r requirements.txt

echo "=== Collecting static files ==="
$VENV/bin/python manage.py collectstatic --noinput

echo "=== Running migrations ==="
$VENV/bin/python manage.py migrate --noinput

echo "=== Restarting Gunicorn ==="
sudo systemctl restart gunicorn

echo "=== Deploy complete ==="
