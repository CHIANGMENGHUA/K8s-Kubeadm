#!/bin/bash

# Deployment script for batch-processing-demo on Kubernetes

set -e

NAMESPACE="default"
MANIFEST_FILE="batch-processing-demo.yml"

echo "🚀 Deploying batch-processing-demo to Kubernetes..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    echo "Make sure your kubeconfig is properly configured"
    exit 1
fi

# Apply the manifests
echo "📋 Applying Kubernetes manifests..."
kubectl apply -f "${MANIFEST_FILE}"

echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/batch-processing-demo-deployment

echo "📊 Checking deployment status..."
kubectl get deployments,services,configmaps,hpa -l app=batch-processing-demo

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📋 Useful commands:"
echo "  View pods:        kubectl get pods -l app=batch-processing-demo"
echo "  View logs:        kubectl logs -l app=batch-processing-demo -f"
echo "  Port forward:     kubectl port-forward svc/batch-processing-demo-service 9191:9191"
echo "  Scale deployment: kubectl scale deployment batch-processing-demo-deployment --replicas=3"
echo "  Delete deployment: kubectl delete -f ${MANIFEST_FILE}"
echo ""
echo "🌐 Access the application:"
echo "  NodePort URL: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'):32191"
echo "  Health Check: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'):32191/actuator/health"