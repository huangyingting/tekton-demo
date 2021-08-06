#!/bin/bash

# Read domain suffix and other environment variables
source aksaz.env

# Create a namespace for cert manager
kubectl create ns cert-manager

# Allow running from spot instance node pool
kubectl annotate ns cert-manager scheduler.alpha.kubernetes.io/defaultTolerations='[{"key":"kubernetes.azure.com/scalesetpriority","operator":"Equal","value":"spot","effect":"NoSchedule"}]'

# Add the cert-manager repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Use Helm to deploy an cert manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.4.0 \
  --set installCRDs=true \
  --set nodeSelector."beta\.kubernetes\.io/os"=linux

# Wait until cert-manager pods are ready to create cluster issuer
while [[ $(kubectl get pods -n cert-manager -l app=webhook -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]
do
  echo "Waiting for cert-manager webhook to be ready..."
  sleep 5
done

# Create letsencrypt certificate cluster issuer 
cat <<EOF | kubectl create -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: cert-manager
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@$DOMAIN
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux      
EOF

