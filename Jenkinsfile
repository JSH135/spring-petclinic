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

        stage('Build & Push Docker Image (on k8s-node02)') {
    environment {
        DOCKER_HOST_NODE = "192.168.20.107"   // k8s-node02 IP
    }
    steps {
        withCredentials([
            usernamePassword(credentialsId: 'docker-hub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')
        ]) {
            sshagent(credentials: ['node02-ssh']) {   // 아까 만든 SSH 크리덴셜 ID
                sh '''
                  echo "[INFO] k8s-node02에서 Docker 이미지 빌드 & 푸시 시작"

                  ssh -o StrictHostKeyChecking=no ubuntu@${DOCKER_HOST_NODE} << 'EOF'
                    set -e

                    echo "[INFO] 작업 디렉토리 준비"
                    cd /home/ubuntu
                    rm -rf spring-petclinic-ci || true
                    mkdir -p spring-petclinic-ci
                    cd spring-petclinic-ci

                    echo "[INFO] Git 소스 가져오기"
                    git clone https://github.com/JSH135/spring-petclinic.git src
                    cd src

                    echo "[INFO] Maven 빌드 (노드에서)"
                    chmod +x mvnw
                    ./mvnw -B -DskipTests package

                    echo "[INFO] Docker Hub 로그인"
                    echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin

                    echo "[INFO] Docker 이미지 빌드 & 태깅"
                    docker build -t josohyun/spring-petclinic:1 .
                    docker tag josohyun/spring-petclinic:1 josohyun/spring-petclinic:latest

                    echo "[INFO] Docker 이미지 푸시"
                    docker push josohyun/spring-petclinic:1
                    docker push josohyun/spring-petclinic:latest
                  EOF
                '''
            }
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
