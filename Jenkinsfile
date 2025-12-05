pipeline {
    agent any

    environment {
        // Docker 이미지
        DOCKER_IMAGE = "josohyun/spring-petclinic"
        DOCKER_TAG   = "latest"

        // Jenkins에 등록한 Docker Hub 자격증명 ID
        DOCKER_CREDS = "dockerhub"

        // Kubernetes
        KUBE_NAMESPACE = "petclinic"
        KUBECONFIG     = "/var/jenkins_home/.kube/config"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/JSH135/spring-petclinic.git'
            }
        }

        stage('Build JAR') {
            steps {
                sh '''
                    echo "[INFO] Maven build 시작"
                    chmod +x mvnw
                    ./mvnw -B -DskipTests package
                '''
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CREDS}",
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "[INFO] Docker Hub 로그인"
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                        echo "[INFO] Docker 이미지 빌드"
                        docker build -t $DOCKER_IMAGE:$DOCKER_TAG .

                        echo "[INFO] Docker 이미지 푸시"
                        docker push $DOCKER_IMAGE:$DOCKER_TAG
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                    echo "[INFO] Kubernetes 배포 시작"

                    kubectl --kubeconfig=$KUBECONFIG -n $KUBE_NAMESPACE set image deployment/petclinic \
                        petclinic=$DOCKER_IMAGE:$DOCKER_TAG

                    kubectl --kubeconfig=$KUBECONFIG -n $KUBE_NAMESPACE rollout status deployment/petclinic \
                        --timeout=120s
                '''
            }
        }
    }
}
