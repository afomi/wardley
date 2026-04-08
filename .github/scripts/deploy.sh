#!/bin/bash
set -e

IMAGE="$1"

# Refresh env from Secrets Manager
SECRETS=$(aws secretsmanager get-secret-value --secret-id wardley/prod --region us-east-1 --query SecretString --output text)
echo "$SECRETS" | jq -r 'to_entries[] | "\(.key)=\(.value)"' > /opt/wardley.env
echo PHX_SERVER=true >> /opt/wardley.env
echo PORT=8080 >> /opt/wardley.env
echo POOL_SIZE=10 >> /opt/wardley.env

# Pull latest image
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker pull "$IMAGE"

# Restart container
docker stop wardley 2>/dev/null || true
docker rm wardley 2>/dev/null || true
INSTANCE_ID=$(ec2-metadata -i | cut -d' ' -f2)
docker run -d --name wardley --restart unless-stopped --env-file /opt/wardley.env --network host \
  --log-driver=awslogs --log-opt awslogs-region=us-east-1 --log-opt awslogs-group=/app/wardley --log-opt awslogs-stream="$INSTANCE_ID" \
  "$IMAGE"
