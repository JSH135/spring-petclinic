pipeline {
    // 항상 docker-builder 에이전트에서 실행
    agent { label 'docker-builder' }

    environment {
        // Docker Hub repo
        DOCKERHUB_REPO = 'josohyun/spring-petclinic'
        // kubectl 이 쓸 kubeconfig 경로 (node02의 jenkins 계정에 맞게)
        KUBECONFIG = '/home/jenkins/.kube/config'
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
                  IMAGE_TAG=${BUILD_NUMBER}

                  docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                  docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                 usernameVariable: 'DOCKER_USER',
                                                 passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                      cd "$WORKSPACE"

                      echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin || exit 1

                      IMAGE_NAME=${DOCKERHUB_REPO}
                      IMAGE_TAG=${BUILD_NUMBER}

                      # 네트워크가 구리면 여기서 오래 걸릴 수 있음
                      docker push ${IMAGE_NAME}:${IMAGE_TAG}
                      docker push ${IMAGE_NAME}:latest
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                  cd "$WORKSPACE"

                  # KUBECONFIG 는 environment 에서 지정됨
                  kubectl config get-contexts

                  # petclinic 네임스페이스 + Deployment + Service + Ingress 동시 적용
                  kubectl apply -f k8s/petclinic.yaml
                '''
            }
        }
    }
}
