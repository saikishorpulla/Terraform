pipeline {
    agent any

    environment {
        AWS_REGION = "ap-south-1"
        CLUSTER_NAME = "demo-eks-cluster"
    }

    stages {
        stage('Checkout') {
            steps {
                git url: 'https://github.com/techcoms/Terraform.git', branch:'main'
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {

                    sh """
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
                sh """
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                """
            }
        }

        stage('Deploy NGINX') {
            steps {
                sh """
                    kubectl apply -f deploymrnt-ngnix.yaml
                    kubectl get pods -l app=nginx
                """
            }
        }
    }
}
