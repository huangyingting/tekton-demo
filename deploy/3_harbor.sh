#!/bin/bash

# Read domain suffix and other environment variables
source aksaz.env

# Create the namespace for harbor installation
kubectl create namespace harbor-system

# Allow running from spot instance node pool
kubectl annotate ns harbor-system scheduler.alpha.kubernetes.io/defaultTolerations='[{"key":"kubernetes.azure.com/scalesetpriority","operator":"Equal","value":"spot","effect":"NoSchedule"}]'

# Add the harbor helm repo 
helm repo add harbor https://helm.goharbor.io
helm repo update

# Install Harbor
helm install harbor harbor/harbor \
    --namespace harbor-system \
    --version 1.7.0 \
    --set expose.tls.certSource=secret \
    --set expose.ingress.hosts.core=harbor.$DOMAIN \
    --set expose.tls.secret.secretName=harbor-tls \
    --set notary.enabled=true \
    --set expose.ingress.hosts.notary=notary.$DOMAIN \
    --set expose.tls.secret.notarySecretName=notary-tls \
    --set trivy.enabled=true \
    --set expose.ingress.annotations."kubernetes\.io/ingress\.class"=nginx \
    --set expose.ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt  \
    --set persistence.enabled=true \
    --set externalURL=https://harbor.$DOMAIN \
    --set harborAdminPassword=$HARBOR_ADMIN_PASSWORD \
    --set persistence.persistentVolumeClaim.registry.storageClass=default \
    --set persistence.persistentVolumeClaim.trivy.storageClass=default \
    --set persistence.persistentVolumeClaim.chartmuseum.storageClass=default \
    --set persistence.persistentVolumeClaim.jobservice.storageClass=default \
    --set persistence.persistentVolumeClaim.database.storageClass=default \
    --set persistence.persistentVolumeClaim.redis.storageClass=default \
    --set persistence.persistentVolumeClaim.registry.size=8Gi \
    --set persistence.persistentVolumeClaim.trivy.size=8Gi \
    --set persistence.persistentVolumeClaim.chartmuseum.size=8Gi \
    --set persistence.persistentVolumeClaim.jobservice.size=4Gi \
    --set persistence.persistentVolumeClaim.database.size=4Gi \
    --set persistence.persistentVolumeClaim.redis.size=4Gi

while [[ $(kubectl get pods -n harbor-system -l app=harbor -l component=core -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]
do
  echo "Waiting for harbor core to be ready..."
  sleep 5
done


while [[ "$(curl -m 15 -s -o /dev/null -w ''%{http_code}'' -i -k -X GET https://harbor.$DOMAIN/api/v2.0/ping)" != "200" ]]
do
  echo "Waiting for harbor exposed rest api to be ready..."
  sleep 5; 
done

curl -u admin:$HARBOR_ADMIN_PASSWORD -i -k -X POST "https://harbor.$DOMAIN/api/v2.0/projects" -d "{\"metadata\":{\"public\":\"false\"},\"project_name\":\"$HARBOR_PROJECT\",\"owner_id\":1,\"owner_name\":\"admin\"}" -H "Content-Type: application/json"
curl -u admin:$HARBOR_ADMIN_PASSWORD -i -k -X POST "https://harbor.$DOMAIN/api/v2.0/users" -d "{\"username\":\"$HARBOR_USER\",\"email\":\"$HARBOR_USER_EMAIL\",\"realname\":\"$HARBOR_USER_REALNAME\",\"password\":\"$HARBOR_USER_PASSWORD\"}" -H "Content-Type: application/json"
PROJECT_ID=$(curl -u admin:$HARBOR_ADMIN_PASSWORD -k -s -X GET "https://harbor.$DOMAIN/api/v2.0/projects?name=$HARBOR_PROJECT" | jq '.[0].project_id')
curl -u admin:$HARBOR_ADMIN_PASSWORD -i -k -X POST "https://harbor.$DOMAIN/api/v2.0/projects/$PROJECT_ID/members" -d "{\"role_id\":2,\"member_user\":{\"username\":\"$HARBOR_USER\"}}" -H "Content-Type: application/json"