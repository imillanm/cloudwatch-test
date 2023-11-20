pipeline{
    agent any
    environment {
        AWS_DEFAULT_REGION="us-west-2"
        THE_BUTLER_SAYS_SO=credentials('cw')
    }
    tools {
        terraform 'terraform-11'
    }
    stages{
        stage('Git checkout'){
            steps{
                git 'https://github.com/cristian2197aravena/cloudwatch-test.git'
            }
        }
        stage('Terraform init'){
            steps{
                sh 'terraform init'
            }
        }
        stage('Terraform plan'){
            when {
                expression { choice == 'plan' }
            }
            steps{
                sh 'terraform plan'
            }
        }
        stage('Terraform apply'){
            when {
                expression { choice == 'apply' }
            }
            steps{
                sh 'terraform apply -auto-approve'
            }
        }
        //este paso es para destruir los subido a aws.
        stage('Terraform destroy'){
            when {
                expression { choice == 'destroy' }
            }
            steps{
                sh 'terraform destroy -auto-approve'
            }
        }
    }
}
