pipeline {
  agent any

  environment {
    AWS_REGION   = "ap-south-1"
    CLUSTER_NAME = "demo-eks-cluster" // fallback
  }

  stages {
    stage('Checkout') {
      steps {
        git url: 'https://github.com/techcoms/Terraform.git', branch: 'main'
      }
    }

    stage('Terraform Apply') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            set -euo pipefail
            rm -rf .terraform .terraform.lock.hcl || true
            terraform init -upgrade
            terraform plan -out=tfplan
            terraform apply -auto-approve tfplan

            CLUSTER_FROM_TF=$(terraform output -raw cluster_name 2>/dev/null || true)
            if [ -z "$CLUSTER_FROM_TF" ]; then
              CLUSTER_FROM_TF="${CLUSTER_NAME}"
            fi
            echo "$CLUSTER_FROM_TF" > cluster_name.txt
          '''
        }
      }
    }

    stage('Update Kubeconfig & Deploy') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv(["AWS_REGION=${env.AWS_REGION}", "AWS_DEFAULT_REGION=${env.AWS_REGION}"]) {
            sh '''
              set -euo pipefail
              CLUSTER=$(cat cluster_name.txt)
              echo "Using cluster: $CLUSTER"

              aws sts get-caller-identity
              aws eks update-kubeconfig --region $AWS_REGION --name "$CLUSTER"

              kubectl apply -f deployment-ngnix.yaml
              kubectl get pods -l app=nginx --no-headers || true
            '''
          }
        }
      }
    }
  }

  post {
    always {
      sh '''
        set +e
        if [ -f cluster_name.txt ]; then
          CLUSTER=$(cat cluster_name.txt)
          echo "Finished. Cluster: $CLUSTER"
          kubectl get nodes --no-headers || true
        fi
      '''
    }
  }
}
