#!/bin/bash

# Create a namespace for nginx ingress
kubectl create namespace nginx

# Allow running from spot instance node pool
kubectl annotate ns nginx scheduler.alpha.kubernetes.io/defaultTolerations='[{"key":"kubernetes.azure.com/scalesetpriority","operator":"Equal","value":"spot","effect":"NoSchedule"}]'

# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Use Helm to deploy an NGINX ingress controller
helm install nginx ingress-nginx/ingress-nginx \
    --version 3.34.0 \
    --namespace nginx \
    --set controller.replicaCount=1 \
    --set defaultBackend.enabled=true \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux

# Get external load balancer ip address
EXTERNAL_IP=""
while [ -z $EXTERNAL_IP ]; do
  echo "Waiting for end point..."
  EXTERNAL_IP=$(kubectl get svc nginx-ingress-nginx-controller -n nginx --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  [ -z "$EXTERNAL_IP" ] && sleep 10
done

# Add external ip address to DNS zone
az network dns record-set a add-record -g AKSAZ -z cn.gok8s.top -n * -a $EXTERNAL_IP