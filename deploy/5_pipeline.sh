#!/bin/bash

# Read domain suffix and other environment variables
source aksaz.env

kubectl create ns $DEPLOY_NAMESPACE
kubectl annotate ns $DEPLOY_NAMESPACE scheduler.alpha.kubernetes.io/defaultTolerations='[{"key":"kubernetes.azure.com/scalesetpriority","operator":"Equal","value":"spot","effect":"NoSchedule"}]'

# Install tekton tasks
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/v1beta1/git/git-clone.yaml -n $DEPLOY_NAMESPACE
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/v1beta1/kaniko/kaniko.yaml -n $DEPLOY_NAMESPACE
kubectl apply -f ../tekton/deploy-using-kubectl.yaml -n $DEPLOY_NAMESPACE

# Create harbor repository secret used in build-and-push task to push image
kubectl create secret generic harbor-registry-secret --type="kubernetes.io/basic-auth" --from-literal=username=$HARBOR_USER --from-literal=password=$HARBOR_USER_PASSWORD -n $DEPLOY_NAMESPACE
kubectl annotate secret harbor-registry-secret tekton.dev/docker-0=harbor.$DOMAIN -n $DEPLOY_NAMESPACE

# Create harbor repository secret used in image pull
kubectl create secret docker-registry regcred --docker-server="https://harbor.$DOMAIN" --docker-username=$HARBOR_USER  --docker-password=$HARBOR_USER_PASSWORD  --docker-email=$HARBOR_USER_EMAIL -n $DEPLOY_NAMESPACE

# Create tekton pipeline and trigger
kubectl apply -f ../tekton/github-pipeline-account.yaml -n $DEPLOY_NAMESPACE
kubectl apply -f ../tekton/github-pipeline.yaml -n $DEPLOY_NAMESPACE
kubectl apply -f ../tekton/github-pipeline-pvc.yaml -n $DEPLOY_NAMESPACE
# kubectl create -f ../tekton/github-pipeline-run.yaml.debug -n $DEPLOY_NAMESPACE
cat ../tekton/github-trigger-account.yaml | sed -e 's/__NAMESPACE__/'"$DEPLOY_NAMESPACE"'/g' | kubectl apply -n $DEPLOY_NAMESPACE -f -

IMAGE_REPOSITORY=harbor.$DOMAIN/$HARBOR_PROJECT
cat ../tekton/github-trigger.yaml | \
sed -e 's/__GITHUB_WEBHOOK_SECRET__/'"$GITHUB_WEBHOOK_SECRET"'/g' \
    -e 's#__IMAGE_REPOSITORY__#'"$IMAGE_REPOSITORY"'#g' \
    -e 's#__PATH_TO_CONTEXT__#'"$PATH_TO_CONTEXT"'#g' \
    -e 's#__PATH_TO_YAML_FILE__#'"$PATH_TO_YAML_FILE"'#g' \
| kubectl apply -n $DEPLOY_NAMESPACE -f -

kubectl apply -n $DEPLOY_NAMESPACE -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $DEPLOY_NAMESPACE-github-trigger
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt      
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /$1  
spec:
  ingressClassName: nginx
  rules:
  - host: $DEPLOY_NAMESPACE.$DOMAIN
    http:
      paths:
      - path: /github
        pathType: ImplementationSpecific
        backend:
          service: 
            name: el-github-listener
            port: 
              number: 8080
  tls:
  - hosts:
    - $DEPLOY_NAMESPACE.$DOMAIN
    secretName: $DEPLOY_NAMESPACE-tls              
EOF