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
        withCredentials([string(credentialsId: 'mern-mongo-uri', variable: 'MONGO_URI')]) {
          sh '''
            set -eu
            set +x
            aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER"
            kubectl create namespace "$KUBE_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

            kubectl create secret generic backend-secrets \
              --namespace "$KUBE_NAMESPACE" \
              --from-literal="MONGO_URI=$MONGO_URI" \
              --from-literal="NODE_ENV=production" \
              --dry-run=client -o yaml | kubectl apply -f -

            export BACKEND_IMAGE_FULL="$ECR_REGISTRY/$ECR_BACKEND:$IMAGE_TAG"
            export FRONTEND_IMAGE_FULL="$ECR_REGISTRY/$ECR_FRONTEND:$IMAGE_TAG"
            envsubst < k8s/backend-deployment.yaml | kubectl apply -n "$KUBE_NAMESPACE" -f -
            envsubst < k8s/frontend-deployment.yaml | kubectl apply -n "$KUBE_NAMESPACE" -f -
            kubectl apply -n "$KUBE_NAMESPACE" -f k8s/backend-service.yaml
            kubectl apply -n "$KUBE_NAMESPACE" -f k8s/frontend-service.yaml

            kubectl rollout status deployment/backend -n "$KUBE_NAMESPACE" --timeout=180s
            kubectl rollout status deployment/frontend -n "$KUBE_NAMESPACE" --timeout=180s
            kubectl get service frontend -n "$KUBE_NAMESPACE" \
              -o jsonpath='Frontend URL: http://{.status.loadBalancer.ingress[0].hostname}{"\\n"}'
          '''
        }
      }
    }
  }
}
