pipeline {
  agent any

  environment {
    AWS_REGION   = "ap-south-1"
    # fallback name if terraform doesn't expose it
    CLUSTER_NAME = "demo-eks-cluster"
    TF_PLAN_FILE = "tfplan"
  }

  stages {
    stage('Checkout') {
      steps {
        git url: 'https://github.com/techcoms/Terraform.git', branch: 'main'
      }
    }

    stage('Terraform Apply') {
      steps {
        // Bind AWS creds into env vars for Terraform
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh """
            set -euo pipefail
            rm -rf .terraform .terraform.lock.hcl || true
            terraform init -upgrade
            terraform plan -out=${TF_PLAN_FILE}
            terraform apply -auto-approve ${TF_PLAN_FILE}
            # try several common terraform output keys to capture cluster name
            # 1) prefer simple raw outputs if available, otherwise fall back to parsing json
            CLUSTER_FROM_TF=""
            CLUSTER_FROM_TF=\$(terraform output -raw cluster_name 2>/dev/null || true)
            if [ -z "\$CLUSTER_FROM_TF" ]; then
              CLUSTER_FROM_TF=\$(terraform output -raw eks_cluster_name 2>/dev/null || true)
            fi
            if [ -z "\$CLUSTER_FROM_TF" ]; then
              CLUSTER_FROM_TF=\$(terraform output -raw cluster_id 2>/dev/null || true)
            fi
            if [ -z "\$CLUSTER_FROM_TF" ]; then
              # try json parsing: pick the first string value in outputs
              TF_JSON=\$(terraform output -json 2>/dev/null || echo "{}")
              CLUSTER_FROM_TF=\$(echo "\$TF_JSON" | jq -r 'to_entries[] | select(.value.value | type == "string") | .value.value' 2>/dev/null | head -n1 || true)
            fi

            if [ -n "\$CLUSTER_FROM_TF" ]; then
              echo ">>> Cluster name discovered from Terraform outputs: \$CLUSTER_FROM_TF"
              echo "\$CLUSTER_FROM_TF" > cluster_name.txt
            else
              echo ">>> No cluster name found in Terraform outputs; using fallback CLUSTER_NAME=${CLUSTER_NAME}"
              echo "${CLUSTER_NAME}" > cluster_name.txt
            fi
          """
        }
      }
    }

    stage('Determine Cluster Name') {
      steps {
        // ensure we have the AWS creds available for describe calls too
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv(["AWS_REGION=${env.AWS_REGION}", "AWS_DEFAULT_REGION=${env.AWS_REGION}"]) {
            sh '''
              set -euo pipefail
              if [ -f cluster_name.txt ] && [ -s cluster_name.txt ]; then
                CLUSTER_NAME_USED=$(cat cluster_name.txt)
              else
                CLUSTER_NAME_USED="${CLUSTER_NAME}"
              fi
              echo "Using cluster name: ${CLUSTER_NAME_USED}"
              echo "${CLUSTER_NAME_USED}" > cluster_name.txt
            '''
          }
        }
      }
    }

    stage('Wait for Cluster Active') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv(["AWS_REGION=${env.AWS_REGION}", "AWS_DEFAULT_REGION=${env.AWS_REGION}"]) {
            sh '''
              set -euo pipefail
              CLUSTER_NAME=$(cat cluster_name.txt)
              echo "Checking cluster status for: $CLUSTER_NAME in region $AWS_REGION"

              # wait up to 15 minutes (900s) for cluster to become ACTIVE
              ATTEMPTS=0
              MAX_ATTEMPTS=45
              SLEEP_SECONDS=20
              while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
                set +e
                STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region $AWS_REGION --query "cluster.status" --output text 2>/dev/null)
                RC=$?
                set -e
                if [ $RC -ne 0 ]; then
                  echo "Cluster not found yet (attempt: $ATTEMPTS). Retrying in $SLEEP_SECONDS seconds..."
                else
                  echo "Cluster status: $STATUS"
                  if [ "$STATUS" = "ACTIVE" ]; then
                    echo "Cluster is ACTIVE."
                    break
                  elif [ "$STATUS" = "CREATING" ] || [ "$STATUS" = "UPDATING" ]; then
                    echo "Cluster is $STATUS. Waiting..."
                  else
                    echo "Cluster is in unexpected state: $STATUS"
                    # continue retrying in case it becomes ACTIVE
                  fi
                fi
                ATTEMPTS=$((ATTEMPTS+1))
                sleep $SLEEP_SECONDS
              done

              if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
                echo "Timed out waiting for cluster to become ACTIVE. Last status: ${STATUS:-UNKNOWN}"
                exit 2
              fi
            '''
          }
        }
      }
    }

    stage('Update Kubeconfig') {
      steps {
        // Re-bind creds for aws cli usage
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv(["AWS_REGION=${env.AWS_REGION}", "AWS_DEFAULT_REGION=${env.AWS_REGION}"]) {
            sh '''
              set -euo pipefail
              CLUSTER_NAME=$(cat cluster_name.txt)
              echo "Updating kubeconfig for cluster: $CLUSTER_NAME"
              aws sts get-caller-identity
              aws eks update-kubeconfig --region $AWS_REGION --name "$CLUSTER_NAME"
              echo "kubeconfig updated; current-context:"
              kubectl config current-context
            '''
          }
        }
      }
    }

    stage('Deploy NGINX') {
      steps {
        // Assumes kubeconfig is configured in $HOME/.kube/config by previous step
        sh """
          set -euo pipefail
          kubectl apply -f deploymrnt-ngnix.yaml
          kubectl rollout status deployment/nginx --timeout=120s || true
          kubectl get pods -l app=nginx -o wide
        """
      }
    }
  } // stages

  post {
    always {
      // show kubeconfig info & recent pod status for debugging
      sh '''
        set +e
        if [ -f cluster_name.txt ]; then
          CLUSTER_NAME=$(cat cluster_name.txt)
          echo "Post-run cluster: $CLUSTER_NAME"
          kubectl get nodes --no-headers || true
          kubectl get pods -A --no-headers || true
        fi
      '''
    }
  }
}
pipeline {
  agent any

  environment {
    AWS_REGION  = "ap-south-1"
    CLUSTER_NAME = "demo-eks-cluster"
  }

  stages {
    stage('Checkout') {
      steps {
        git url: 'https://github.com/techcoms/Terraform.git', branch: 'main'
      }
    }

    stage('Terraform Apply') {
      steps {
        // Bind AWS creds into env vars for Terraform
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh """
            set -euo pipefail
            rm -rf .terraform .terraform.lock.hcl
            terraform init -upgrade
            terraform plan -out=tfplan
            terraform apply -auto-approve tfplan
          """
        }
      }
    }

    stage('Update Kubeconfig') {
      steps {
        // Re-bind creds for aws cli usage
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv(["AWS_REGION=${env.AWS_REGION}", "AWS_DEFAULT_REGION=${env.AWS_REGION}"]) {
            sh '''
              set -euo pipefail
              aws sts get-caller-identity
              aws eks update-kubeconfig --region $AWS_REGION --name ${CLUSTER_NAME}
            '''
          }
        }
      }
    }

    stage('Deploy NGINX') {
      steps {
        // Assumes kubeconfig is configured in $HOME/.kube/config by previous step
        sh """
          set -euo pipefail
          kubectl apply -f deploymrnt-ngnix.yaml
          kubectl get pods -l app=nginx
        """
      }
    }
  } 
} 
