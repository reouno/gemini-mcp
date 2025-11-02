#!/bin/bash
set -euo pipefail

# Default values
REGION="asia-northeast1"
MEMORY="512Mi"
CPU="1"
MIN_INSTANCES="0"
MAX_INSTANCES="10"
SERVICE_NAME="gemini-mcp"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --project-id=*)
      PROJECT_ID="${1#*=}"
      shift
      ;;
    --region=*)
      REGION="${1#*=}"
      shift
      ;;
    --gemini-api-key=*)
      GEMINI_API_KEY="${1#*=}"
      shift
      ;;
    --memory=*)
      MEMORY="${1#*=}"
      shift
      ;;
    --cpu=*)
      CPU="${1#*=}"
      shift
      ;;
    --min-instances=*)
      MIN_INSTANCES="${1#*=}"
      shift
      ;;
    --max-instances=*)
      MAX_INSTANCES="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --project-id=ID           GCP project ID"
      echo "  --region=REGION           GCP region (default: asia-northeast1)"
      echo "  --gemini-api-key=KEY      Gemini API key"
      echo "  --memory=SIZE             Memory allocation (default: 512Mi)"
      echo "  --cpu=COUNT               CPU count (default: 1)"
      echo "  --min-instances=N         Minimum instances (default: 0)"
      echo "  --max-instances=N         Maximum instances (default: 10)"
      echo "  -h, --help                Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "${PROJECT_ID:-}" ]; then
  echo "Error: --project-id is required"
  echo "Use --help for usage information"
  exit 1
fi

if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "Error: --gemini-api-key is required"
  echo "Use --help for usage information"
  exit 1
fi

# Show settings
echo ""
echo "=== Deployment Configuration ==="
echo "GCP Project ID:    $PROJECT_ID"
echo "Region:            $REGION"
echo "Service Name:      $SERVICE_NAME"
echo "Memory:            $MEMORY"
echo "CPU:               $CPU"
echo "Min Instances:     $MIN_INSTANCES"
echo "Max Instances:     $MAX_INSTANCES"
echo "API Key:           ${GEMINI_API_KEY:0:10}..."
echo "==============================="
echo ""

IMAGE_URL="$REGION-docker.pkg.dev/$PROJECT_ID/gemini-mcp/$SERVICE_NAME:latest"

echo ""
echo "Step 1/5: Setting project..."
gcloud config set project "$PROJECT_ID"

echo ""
echo "Step 2/5: Building Docker image..."
docker build -t "$IMAGE_URL" .

echo ""
echo "Step 3/5: Configuring Docker authentication..."
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

echo ""
echo "Step 4/5: Pushing image to Artifact Registry..."
docker push "$IMAGE_URL"

echo ""
echo "Step 5/5: Deploying to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE_URL" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars "GEMINI_API_KEY=$GEMINI_API_KEY" \
  --memory "$MEMORY" \
  --cpu "$CPU" \
  --min-instances "$MIN_INSTANCES" \
  --max-instances "$MAX_INSTANCES" \
  --timeout 600

echo ""
echo "========================================="
echo "✅ Deployment Completed!"
echo "========================================="
echo ""
echo "Service URL:"
gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" \
  --format="value(status.url)"
echo ""
echo "MCP Endpoint:"
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" \
  --format="value(status.url)")
echo "$SERVICE_URL/mcp"
echo ""
echo "Test with:"
echo "  curl $SERVICE_URL/health"
echo "========================================="
