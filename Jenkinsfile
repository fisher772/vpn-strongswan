pipeline {
    options {
        timestamps()
    }
    agent any

    environment {
        DOCKER_REGISTRY = 'docker.io'
        GITHUB_REGISTRY = 'ghcr.io'
        GITHUB_REPO = 'git@github.com:fisher772/vpn-strongswan.git'
        DOCKER_CREDENTIALS_ID = '96e24cf7-138e-47b1-9f4e-4afb24beae17'
        GITHUB_CREDENTIALS_ID = '1e833fde-1802-4693-b97a-4018ad1cad30'
        SSH_CREDENTIALS_ID = '80fe90d0-7bac-4cc7-b1a5-b13620509ad0'
        SSH_HOST = credentials('b138f260-88ae-4b9f-ac1c-69c7244b5604')
        SSH_PORT = credentials('371e8bbb-994c-4bc0-a41c-6101705a0bc5')
        SSH_HOST_NAME = credentials('d12d3e0c-bd37-4b00-bfb3-eddbb3618175')
        IMAGE_NAME = 'fisher772/vpn-strongswan'
        DIR_NAME = 'vpn-strongswan'
        CONTAINER_NAME = 'vpn-strongswan'
        CONTAINER_STATUS = "docker inspect --format='{{json .State.Running}}' ${CONTAINER_NAME}"
        TG_TOKEN = credentials('ca26c9a5-deb0-40f6-8dda-80e7ea3cee8a')
        TG_CHAT_ID = credentials('edc71d95-6e6c-4e5d-81ea-fe6331370e05')
        TG_URL = 'https://api.telegram.org/bot${TG_TOKEN}/sendMessage -d chat_id=${TG_CHAT_ID}'
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    def tag = sh(script: 'git tag -l | sort -r | head -n 1', returnStdout: true).trim()
                    env.TAG = tag
                    echo "Processing new tag: ${TAG}"
                    sh "curl -s -X POST ${TG_URL} -d text='Workflow for ${IMAGE_NAME} ${TAG} started!'"
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    if (TAG?.trim()) {
                        sh 'docker build -q -t ${IMAGE_NAME}:${TAG} .'
                        sh 'docker build -q -t ${IMAGE_NAME}:latest .'
                    }
                    else {
                        error 'No tag found'
                    }
                }
            }
        }

        stage('Test image') {
            steps {
                script {
                    sh """
                            cat << EOF > .env
                            IMAGE=${IMAGE_NAME}:${TAG}
                            ${GLOBAR_THREEXUI_ENV_ARRAY}
                            EOF
                       """
                    sh 'docker compose -f workflow-compose.yml up -d'
                    def test_image = sh(script: CONTAINER_STATUS, returnStdout: true).trim()
                    if (test_image == 'true') {
                        sh 'docker compose -f workflow-compose.yml down'
                        echo 'Container is running'
                    }
                    else if (test_image == 'false') {
                        sh 'docker compose -f workflow-compose.yml down'
                        error 'Container is not running'
                    }
                }
            }
        }

        stage('Push to Docker Registry') {
            steps {
                script {
                    docker.withRegistry('', DOCKER_CREDENTIALS_ID) {
                        sh 'docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${TAG}'
                        sh 'docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest'
                    }
                }
            }
        }

        stage('Push to GitHub Registry') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: env.GITHUB_CREDENTIALS_ID, passwordVariable: 'GITHUB_TOKEN', usernameVariable: 'GITHUB_USER')]) {
                        sh 'docker login ghcr.io -u ${GITHUB_USER} -p ${GITHUB_TOKEN}'
                        sh """
                                docker tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:${TAG} ${GITHUB_REGISTRY}/${IMAGE_NAME}:${TAG} && \
                                docker tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:${TAG} ${GITHUB_REGISTRY}/${IMAGE_NAME}:latest
                           """
                        sh 'docker push ${GITHUB_REGISTRY}/${IMAGE_NAME}:${TAG}'
                        sh 'docker push ${GITHUB_REGISTRY}/${IMAGE_NAME}:latest'
                    }
                }
            }
        }

        stage('Deploy to Production') {
            steps {
                script {
                    def remote = [:]
                    remote.name = SSH_HOST_NAME
                    remote.host = SSH_HOST
                    remote.port = SSH_PORT.toInteger()
                    //remote.sudo = true
                    remote.allowAnyHosts = true

                    withCredentials([sshUserPrivateKey(credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                        remote.user = SSH_USER
                        remote.identityFile = SSH_KEY

                        sshCommand remote: remote, command: """
                            git clone ${GITHUB_REPO} && \
                            cd ${DIR_NAME}/ && \
                            docker compose up -d && \
                            rm -rf ../${DIR_NAME} && \
                            ${CONTAINER_STATUS}
                        """
                    }
                }
            }
        }

        stage('Clean workspace') {
            steps {
                script {
                    deleteDir()
                }
            }
        }
    }

    post {
        success {
            script {
                def PIPE_DURATION = currentBuild.durationString
                echo 'Pipeline completed successfully!'
                sh "curl -s -X POST ${TG_URL} -d text='Workflow for ${IMAGE_NAME} ${TAG} completed! Pipeline duration: ${PIPE_DURATION}'"
                echo "Elapsed time: ${PIPE_DURATION}"
            }
        }
        failure {
            script {
                def PIPE_DURATION = currentBuild.durationString
                echo 'Pipeline failed!'
                sh "curl -s -X POST ${TG_URL} -d text='Workflow for ${IMAGE_NAME} ${TAG} failed! Pipeline duration: ${PIPE_DURATION}'"
            }
        }
    }
}
