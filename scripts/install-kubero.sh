#!/bin/bash

# Exit on any error
set -e

echo "Starting Helm and Kubero installation..."

# Install required packages
echo "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y nfs-common nginx

# Install MetalLB for load balancing
echo "Installing MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
echo "Waiting for MetalLB pods to be ready..."
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app=metallb \
    --timeout=90s

# Configure MetalLB with IP range (adjust this range according to your VirtualBox network)
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.56.100-192.168.56.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF

# Install NGINX Ingress Controller
echo "Installing NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=LoadBalancer

# Wait for NGINX Ingress Controller to be ready
echo "Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s

# Install Helm if not already installed
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "Helm is already installed"
fi

# Add Kubero Helm repository
echo "Adding Kubero Helm repository..."
helm repo add kubero https://kubero.github.io/charts/
helm repo update

# Create namespace for Kubero
echo "Creating kubero namespace..."
kubectl create namespace kubero --dry-run=client -o yaml | kubectl apply -f -

# Install local-path-provisioner for storage
echo "Installing local-path storage provisioner..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Install Kubero using Helm
echo "Installing Kubero..."
helm upgrade --install kubero kubero/kubero \
    --namespace kubero \
    --create-namespace \
    --set ingress.enabled=true \
    --set ingress.hosts[0].host=kuberovm.lab \
    --set ingress.hosts[0].paths[0].path=/ \
    --set ingress.hosts[0].paths[0].pathType=Prefix \
    --set ingress.annotations."kubernetes\.io/ingress\.class"=nginx \
    --set persistence.enabled=true \
    --set persistence.size=20Gi

# Add entry to /etc/hosts
echo "Adding kuberovm.lab to /etc/hosts..."
INGRESS_IP=$(kubectl -n ingress-nginx get service ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ ! -z "$INGRESS_IP" ]; then
    sudo sh -c "echo '$INGRESS_IP kuberovm.lab' >> /etc/hosts"
fi

echo "Kubero installation completed!"
echo ""
echo "Important information:"
echo "Ingress IP: $INGRESS_IP"
echo "Hostname: kuberovm.lab"
echo ""
echo "To get the admin password, run:"
echo "kubectl -n kubero get secret kubero -o jsonpath='{.data.admin-password}' | base64 -d"
echo ""
echo "To check the status of Kubero pods, run:"
echo "kubectl -n kubero get pods"
echo ""
echo "Access Kubero at: https://kuberovm.lab"
echo ""
echo "Note: If you're accessing Kubero from another machine, add this line to your hosts file:"
echo "$INGRESS_IP kuberovm.lab"
