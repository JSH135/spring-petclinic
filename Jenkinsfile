pipeline {
    agent { label 'docker-builder' }

    environment {
        DOCKERHUB_REPO = 'josohyun/spring-petclinic'
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        KUBECONFIG     = '/home/jenkins/.kube/config'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build JAR') {
            steps {
                sh '''
                  cd "$WORKSPACE"
                  export MAVEN_OPTS="-Xmx512m"
                  chmod +x mvnw
                  ./mvnw -B -V -DskipTests package
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                  cd "$WORKSPACE"

                  IMAGE_NAME=${DOCKERHUB_REPO}
                  IMAGE_TAG=${IMAGE_TAG}

                  docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                  docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                '''
            }
        }

        // kubelet이 쓰는 containerd(k8s.io)에 이미지 자동 로딩
        stage('Load Image into containerd') {
            steps {
                sh '''
                  cd "$WORKSPACE"

                  IMAGE_NAME=${DOCKERHUB_REPO}
                  IMAGE_TAG=${IMAGE_TAG}
                  TAR=/tmp/spring-petclinic-${IMAGE_TAG}.tar

                  # Docker -> tar
                  docker save ${IMAGE_NAME}:${IMAGE_TAG} -o ${TAR}

                  # tar -> containerd(k8s.io 네임스페이스)
                  # jenkins 계정이 sudo 없이 ctr 실행 가능해야 함 (sudoers 설정 필요)
                  sudo ctr -n k8s.io images import ${TAR}

                  rm -f ${TAR}
                '''
            }
        }

        // Docker Hub push는 "되면 좋고, 안 되면 경고만 찍고 계속 진행"
        stage('Push Docker Image (best effort)') {
            steps {
                script {
                    try {
                        timeout(time: 5, unit: 'MINUTES') {
                            withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                             usernameVariable: 'DOCKER_USER',
                                                             passwordVariable: 'DOCKER_PASS')]) {
                                sh '''
                                  cd "$WORKSPACE"

                                  echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                                  IMAGE_NAME=${DOCKERHUB_REPO}
                                  IMAGE_TAG=${IMAGE_TAG}

                                  docker push ${IMAGE_NAME}:${IMAGE_TAG} || echo "[WARN] push tag ${IMAGE_TAG} failed"
                                  docker push ${IMAGE_NAME}:latest      || echo "[WARN] push latest failed"
                                '''
                            }
                        }
                    } catch (err) {
                        echo "[WARN] Docker push failed or timed out: ${err}"
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                  cd "$WORKSPACE"

                  # 적용 대상 매니페스트: k8s/petclinic.yaml
                  # 이 안에 Deployment + Service + Ingress + (DB 연동 env/Secret) 모두 정의되어 있어야 함
                  kubectl apply -f k8s/petclinic.yaml

                  # 롤아웃 상태 확인
                  kubectl rollout status deployment/petclinic -n petclinic
                '''
            }
        }
    }
}
