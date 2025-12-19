#!/bin/bash
# ARB Translator Gen Z - Deployment Script
# Supports Docker, Kubernetes, and Cloud Functions deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="arb-translator-gen-z"
VERSION="3.2.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed. Please install Docker first."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_warning "Docker Compose not found. Some features may not work."
    fi
}

# Build Docker image
build_docker() {
    log_info "Building Docker image..."
    docker build -t $PROJECT_NAME:$VERSION -t $PROJECT_NAME:latest .
    log_success "Docker image built successfully"
}

# Deploy locally with Docker Compose
deploy_local() {
    log_info "Deploying locally with Docker Compose..."

    # Create necessary directories
    mkdir -p config projects logs

    # Copy example config if it doesn't exist
    if [ ! -f config/config.yaml ]; then
        cp config.yaml.example config/config.yaml
        log_warning "Created default config. Please edit config/config.yaml with your API keys."
    fi

    # Start services
    docker-compose up -d
    log_success "Local deployment completed"
    log_info "Web GUI: http://localhost:8080"
    log_info "WebSocket: ws://localhost:8081"
}

# Deploy to Kubernetes
deploy_kubernetes() {
    log_info "Deploying to Kubernetes..."

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is required for Kubernetes deployment"
        exit 1
    fi

    # Create namespace
    kubectl create namespace arb-translator --dry-run=client -o yaml | kubectl apply -f -

    # Apply Kubernetes manifests
    kubectl apply -f k8s/

    log_success "Kubernetes deployment completed"
    log_info "Check status with: kubectl get pods -n arb-translator"
}

# Deploy to Google Cloud Functions
deploy_cloud_functions() {
    log_info "Deploying to Google Cloud Functions..."

    # Check if gcloud is available
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is required for Cloud Functions deployment"
        exit 1
    fi

    # Set project (would be parameterized in real deployment)
    # gcloud config set project YOUR_PROJECT_ID

    # Deploy function
    gcloud functions deploy arb-translator-api \
        --runtime python39 \
        --trigger-http \
        --allow-unauthenticated \
        --source cloud-functions \
        --entry-point arb_translator_cloud_function \
        --set-env-vars "OPENAI_API_KEY=${OPENAI_API_KEY}"

    log_success "Cloud Functions deployment completed"
}

# Deploy to AWS Lambda
deploy_lambda() {
    log_info "Deploying to AWS Lambda..."

    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is required for Lambda deployment"
        exit 1
    fi

    # Build Lambda package
    cd cloud-functions
    mkdir -p package
    pip install -r requirements.txt -t package/

    # Create deployment package
    cp main.py package/
    cd package
    zip -r ../lambda-deployment.zip .

    # Deploy to Lambda
    aws lambda create-function \
        --function-name arb-translator-api \
        --runtime python3.9 \
        --handler main.arb_translator_cloud_function \
        --role arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-role \
        --zip-file fileb://../lambda-deployment.zip

    log_success "AWS Lambda deployment completed"
}

# Show usage
show_usage() {
    echo "ARB Translator Gen Z - Deployment Script v$VERSION"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build         Build Docker image"
    echo "  local         Deploy locally with Docker Compose"
    echo "  kubernetes    Deploy to Kubernetes cluster"
    echo "  cloud-functions Deploy to Google Cloud Functions"
    echo "  lambda        Deploy to AWS Lambda"
    echo "  all           Build and deploy locally"
    echo "  help          Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  OPENAI_API_KEY     OpenAI API key"
    echo "  DEEPL_API_KEY      DeepL API key"
    echo "  AZURE_TRANSLATOR_KEY Azure Translator key"
    echo "  GOOGLE_TRANSLATE_API_KEY Google Translate API key"
    echo ""
    echo "Examples:"
    echo "  $0 build"
    echo "  $0 local"
    echo "  OPENAI_API_KEY=your_key $0 cloud-functions"
}

# Main deployment logic
main() {
    local command="${1:-help}"

    case $command in
        build)
            check_dependencies
            build_docker
            ;;
        local)
            check_dependencies
            build_docker
            deploy_local
            ;;
        kubernetes)
            deploy_kubernetes
            ;;
        cloud-functions)
            deploy_cloud_functions
            ;;
        lambda)
            deploy_lambda
            ;;
        all)
            check_dependencies
            build_docker
            deploy_local
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
