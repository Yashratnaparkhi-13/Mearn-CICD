pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  environment {
    AWS_REGION = 'ap-south-1'
    EKS_CLUSTER = 'mern-cicd-eks'
    ECR_BACKEND = 'mern-cicd/backend'
    ECR_FRONTEND = 'mern-cicd/frontend'
    KUBE_NAMESPACE = 'mern-staging'
    MONGO_SECRET_ID = 'mern-cicd/mongodb-credentials'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Test') {
      parallel {
        stage('Backend tests') {
          steps {
            dir('backend') {
              sh 'npm ci'
              sh 'npm test -- --runInBand'
            }
          }
        }
        stage('Frontend tests') {
          steps {
            dir('frontend') {
              sh 'npm ci'
              sh 'CI=true npm test -- --watch=false'
            }
          }
        }
      }
    }

    stage('Build and push images') {
      steps {
        script {
          env.AWS_ACCOUNT_ID = sh(
            script: 'aws sts get-caller-identity --query Account --output text',
            returnStdout: true
          ).trim()
          env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(8)}"
        }
        sh '''
          set -eu
          for repository in "$ECR_BACKEND" "$ECR_FRONTEND"; do
            aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$repository" >/dev/null 2>&1 ||
              aws ecr create-repository --region "$AWS_REGION" --repository-name "$repository" >/dev/null
          done
          aws ecr get-login-password --region "$AWS_REGION" |
            docker login --username AWS --password-stdin "$ECR_REGISTRY"

          docker build -t "$ECR_REGISTRY/$ECR_BACKEND:$IMAGE_TAG" ./backend
          docker build \
            --build-arg REACT_APP_API_URL=/api \
            --build-arg REACT_APP_VERSION="$IMAGE_TAG" \
            -t "$ECR_REGISTRY/$ECR_FRONTEND:$IMAGE_TAG" ./frontend
          docker push "$ECR_REGISTRY/$ECR_BACKEND:$IMAGE_TAG"
          docker push "$ECR_REGISTRY/$ECR_FRONTEND:$IMAGE_TAG"
        '''
      }
    }

    stage('Deploy to EKS staging') {
      steps {
        sh '''
          set -eu
          set +x
          aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER"
          kubectl create namespace "$KUBE_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

          MONGO_SECRET="$(aws secretsmanager get-secret-value \
            --region "$AWS_REGION" \
            --secret-id "$MONGO_SECRET_ID" \
            --query SecretString \
            --output text)"
          MONGO_USER="$(printf '%s' "$MONGO_SECRET" | jq -r .username)"
          MONGO_PASSWORD="$(printf '%s' "$MONGO_SECRET" | jq -r .password)"
          MONGO_URI="mongodb://$MONGO_USER:$MONGO_PASSWORD@mongodb.$KUBE_NAMESPACE.svc.cluster.local:27017/mern_cicd?authSource=admin"

          kubectl create secret generic mongodb-auth \
            --namespace "$KUBE_NAMESPACE" \
            --from-literal="MONGO_INITDB_ROOT_USERNAME=$MONGO_USER" \
            --from-literal="MONGO_INITDB_ROOT_PASSWORD=$MONGO_PASSWORD" \
            --dry-run=client -o yaml | kubectl apply -f -
          kubectl create secret generic backend-secrets \
            --namespace "$KUBE_NAMESPACE" \
            --from-literal="MONGO_URI=$MONGO_URI" \
            --from-literal="NODE_ENV=production" \
            --dry-run=client -o yaml | kubectl apply -f -

          kubectl apply -n "$KUBE_NAMESPACE" -f k8s/mongodb.yaml
          kubectl rollout status statefulset/mongodb -n "$KUBE_NAMESPACE" --timeout=300s

          export BACKEND_IMAGE_FULL="$ECR_REGISTRY/$ECR_BACKEND:$IMAGE_TAG"
          export FRONTEND_IMAGE_FULL="$ECR_REGISTRY/$ECR_FRONTEND:$IMAGE_TAG"
          envsubst < k8s/backend-deployment.yaml | kubectl apply -n "$KUBE_NAMESPACE" -f -
          envsubst < k8s/frontend-deployment.yaml | kubectl apply -n "$KUBE_NAMESPACE" -f -
          kubectl apply -n "$KUBE_NAMESPACE" -f k8s/backend-service.yaml
          kubectl apply -n "$KUBE_NAMESPACE" -f k8s/frontend-service.yaml

          kubectl rollout status deployment/backend -n "$KUBE_NAMESPACE" --timeout=180s
          kubectl rollout status deployment/frontend -n "$KUBE_NAMESPACE" --timeout=180s
          NODE_IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')"
          if [ -z "$NODE_IP" ]; then
            echo "No public worker-node IP is available for the frontend NodePort." >&2
            exit 1
          fi
          kubectl get service frontend -n "$KUBE_NAMESPACE" \
            -o name
          printf 'Frontend URL: http://%s:30080\\n' "$NODE_IP"
        '''
      }
    }
  }
}
