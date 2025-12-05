pipeline {
    agent any

    environment {
        // Docker 이미지 이름
        DOCKER_IMAGE = "josohyun/spring-petclinic"
        DOCKER_TAG   = "latest"              // 필요하면 "build-${BUILD_NUMBER}" 등으로 바꿔도 됨

        // Jenkins 에 등록해 둔 Docker Hub 크리덴셜 ID
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
                    ./mvnw -q -DskipTests package
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

                    # 이미지 태그만 바꿔서 롤링 업데이트
                    kubectl --kubeconfig=$KUBECONFIG -n $KUBE_NAMESPACE set image deployment/petclinic \
                        petclinic=$DOCKER_IMAGE:$DOCKER_TAG

                    # 롤아웃 완료까지 대기
                    kubectl --kubeconfig=$KUBECONFIG -n $KUBE_NAMESPACE rollout status deployment/petclinic \
                        --timeout=120s
                '''
            }
        }
    }
}
