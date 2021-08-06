#!/bin/bash

# Read domain suffix and other environment variables
source aksaz.env

# Create a namespace for tekton
kubectl create ns tekton-pipelines

# Allow running from spot instance node pool
kubectl annotate ns tekton-pipelines scheduler.alpha.kubernetes.io/defaultTolerations='[{"key":"kubernetes.azure.com/scalesetpriority","operator":"Equal","value":"spot","effect":"NoSchedule"}]'

kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.26.0/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/v0.15.0/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/v0.15.0/interceptors.yaml
kubectl apply -f https://github.com/tektoncd/dashboard/releases/download/v0.18.1/tekton-dashboard-release.yaml

kubectl apply -n tekton-pipelines -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tekton-dashboard
  namespace: tekton-pipelines
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt      
spec:
  ingressClassName: nginx
  rules:
  - host: tekton.$DOMAIN
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: tekton-dashboard
            port:
              number: 9097
  tls:
  - hosts:
    - tekton.$DOMAIN
    secretName: tekton-dashboard-tls
EOF