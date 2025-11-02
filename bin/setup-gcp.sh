#!/bin/bash
set -euo pipefail

# Default values
REGION="asia-northeast1"
GITHUB_REPO="gemini-mcp"

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
    --github-user=*)
      GITHUB_USER="${1#*=}"
      shift
      ;;
    --github-repo=*)
      GITHUB_REPO="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --project-id=ID       GCP project ID"
      echo "  --region=REGION       GCP region (default: asia-northeast1)"
      echo "  --github-user=USER    GitHub username"
      echo "  --github-repo=REPO    GitHub repository name (default: gemini-mcp)"
      echo "  -h, --help            Show this help message"
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

if [ -z "${GITHUB_USER:-}" ]; then
  echo "Error: --github-user is required"
  echo "Use --help for usage information"
  exit 1
fi

# Show settings
echo ""
echo "=== Setup Configuration ==="
echo "GCP Project ID:    $PROJECT_ID"
echo "Region:            $REGION"
echo "GitHub User:       $GITHUB_USER"
echo "GitHub Repo:       $GITHUB_REPO"
echo "=========================="
echo ""

echo ""
echo "Verifying prerequisites..."

# Check if project exists
if ! gcloud projects describe "$PROJECT_ID" &>/dev/null; then
  echo "❌ Error: GCP project '$PROJECT_ID' does not exist."
  echo ""
  echo "Please create the project first:"
  echo "  1. Go to: https://console.cloud.google.com/projectcreate"
  echo "  2. Create a project with ID: $PROJECT_ID"
  echo "  3. Link a billing account to the project"
  echo ""
  exit 1
fi

echo "✓ Project '$PROJECT_ID' exists"

# Check if billing is enabled (by trying to check enabled services)
if ! gcloud services list --project="$PROJECT_ID" &>/dev/null; then
  echo "❌ Error: Cannot access project services. Billing account may not be linked."
  echo ""
  echo "Please link a billing account:"
  echo "  1. Go to: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
  echo "  2. Link an existing billing account (or create a new one)"
  echo ""
  exit 1
fi

echo "✓ Billing account is linked"
echo ""

echo "Step 1/6: Setting project and enabling APIs..."
gcloud config set project "$PROJECT_ID"
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable iamcredentials.googleapis.com

echo ""
echo "Step 2/6: Creating Artifact Registry repository..."
if gcloud artifacts repositories describe gemini-mcp --location="$REGION" &>/dev/null; then
  echo "Artifact Registry repository already exists, skipping creation."
else
  gcloud artifacts repositories create gemini-mcp \
    --repository-format=docker \
    --location="$REGION" \
    --description="Gemini MCP Server container images"
fi

echo ""
echo "Step 3/6: Creating service account for GitHub Actions..."
if gcloud iam service-accounts describe "github-actions@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null; then
  echo "Service account already exists, skipping creation."
else
  gcloud iam service-accounts create github-actions \
    --display-name="GitHub Actions Service Account"
fi

echo ""
echo "Step 4/6: Granting IAM roles..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

echo ""
echo "Step 5/6: Creating Workload Identity Pool..."
if gcloud iam workload-identity-pools describe github-pool --location="global" &>/dev/null; then
  echo "Workload Identity Pool already exists, skipping creation."
else
  gcloud iam workload-identity-pools create github-pool \
    --location="global" \
    --display-name="GitHub Actions Pool"
fi

echo ""
echo "Step 6/6: Creating Workload Identity Provider..."
if gcloud iam workload-identity-pools providers describe github-provider \
  --location="global" \
  --workload-identity-pool="github-pool" &>/dev/null; then
  echo "Workload Identity Provider already exists, skipping creation."
else
  gcloud iam workload-identity-pools providers create-oidc github-provider \
    --location="global" \
    --workload-identity-pool="github-pool" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository_owner=='$GITHUB_USER'"
fi

echo ""
echo "Configuring Workload Identity User role..."
WORKLOAD_IDENTITY_POOL_ID=$(gcloud iam workload-identity-pools describe github-pool \
  --location="global" \
  --format="value(name)")

gcloud iam service-accounts add-iam-policy-binding \
  "github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/$WORKLOAD_IDENTITY_POOL_ID/attribute.repository/$GITHUB_USER/$GITHUB_REPO"

echo ""
echo "========================================="
echo "✅ GCP Setup Completed!"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Get your Gemini API key from: https://aistudio.google.com/app/apikey"
echo ""
echo "2. Set the following GitHub Secrets in your repository:"
echo "   (Go to: https://github.com/$GITHUB_USER/$GITHUB_REPO/settings/secrets/actions)"
echo ""
echo "   GCP_PROJECT_ID=$PROJECT_ID"
echo ""
echo -n "   WIF_PROVIDER="
gcloud iam workload-identity-pools providers describe github-provider \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --format="value(name)"
echo ""
echo "   WIF_SERVICE_ACCOUNT=github-actions@$PROJECT_ID.iam.gserviceaccount.com"
echo ""
echo "   GEMINI_API_KEY=(paste your API key here)"
echo ""
echo "3. Push to main branch to trigger deployment:"
echo "   git push origin main"
echo ""
echo "========================================="
