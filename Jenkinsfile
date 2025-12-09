pipeline {
    agent {
        kubernetes {
            label 'kaniko-build'
            defaultContainer 'jnlp'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: kaniko-build
spec:
  serviceAccountName: jenkins

  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
    - key: "node.kubernetes.io/disk-pressure"
      operator: "Exists"
      effect: "NoSchedule"

  containers:
    # --------------------------------------
    # Kaniko Container (Docker Build & Push)
    # --------------------------------------
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      tty: true
      command: ["/bin/sh"]
      args: ["-c", "sleep infinity"]
      securityContext:
        runAsUser: 0
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
          ephemeral-storage: 2Gi
        limits:
          cpu: "1"
          memory: "2Gi"
          ephemeral-storage: 5Gi
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker/config.json
          subPath: config.json
        - name: workspace-volume
          mountPath: /home/jenkins/agent/workspace/
        - name: kaniko-cache
          mountPath: /kaniko/cache

    # --------------------------------------
    # Maven Container (Java Build)
    # --------------------------------------
    - name: maven
      image: maven:3.9.6-eclipse-temurin-17
      tty: true
      command: ["/bin/sh"]
      args: ["-c", "sleep infinity"]
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
          ephemeral-storage: 2Gi
        limits:
          cpu: "1"
          memory: "2Gi"
          ephemeral-storage: 5Gi
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent/workspace/
        - name: maven-cache
          mountPath: /root/.m2

    # --------------------------------------
    # Kubectl Container (배포용)
    #   - 여기 이미지는 공식 이미지/버전으로 교체 가능
    # --------------------------------------
    - name: kubectl
      image: lachlanevenson/k8s-kubectl:v1.30.0
      tty: true
      command: ["cat"]
      args: [""]
      resources:
        requests:
          cpu: "250m"
          memory: "512Mi"
          ephemeral-storage: 1Gi
        limits:
          cpu: "500m"
          memory: "1Gi"
          ephemeral-storage: 2Gi
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent/workspace/

    # --------------------------------------
    # JNLP Agent
    # --------------------------------------
    - name: jnlp
      image: jenkins/inbound-agent:latest
      resources:
        requests:
          cpu: "100m"
          memory: "256Mi"
          ephemeral-storage: 500Mi
        limits:
          cpu: "500m"
          memory: "512Mi"
          ephemeral-storage: 1Gi
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent/workspace/

  # --------------------------------------
  # VOLUMES
  # --------------------------------------
  volumes:
    # Docker Hub 로그인 정보 (kubectl 네임스페이스: jenkins 에 미리 생성)
    - name: docker-config
      secret:
        secretName: dockertoken
        items:
          - key: ".dockerconfigjson"
            path: config.json

    # Jenkins workspace
    - name: workspace-volume
      emptyDir: {}

    # Maven cache
    - name: maven-cache
      emptyDir: {}

    # Kaniko cache
    - name: kaniko-cache
      emptyDir: {}
"""
        }
    }

    environment {
        // ====== 여기만 본인 환경에 맞게 설정 ======
        REGISTRY      = "docker.io/josohyun"
        IMAGE         = "spring-petclinic"
        TAG           = "${BUILD_NUMBER}"   // 1,2,3,... 자동 증가
        K8S_NAMESPACE = "petclinic"
        K8S_DEPLOY    = "petclinic"
        K8S_CONTAINER = "petclinic"
    }

    stages {

        // ------------------------------------------------------
        // 1) Git Checkout
        // ------------------------------------------------------
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/JSH135/spring-petclinic.git'
            }
        }

        // ------------------------------------------------------
        // 2) Maven Build (JAR 생성)
        // ------------------------------------------------------
        stage('Maven Build') {
            steps {
                container('maven') {
                    sh """
export HOME=\$WORKSPACE

mvn clean package \\
  -DskipTests \\
  -Dcheckstyle.skip=true \\
  -Dmaven.repo.local=/root/.m2
"""
                }
            }
        }

        // ------------------------------------------------------
        // 3) Kaniko Build & Push (Docker 이미지 빌드 + Docker Hub 푸시)
        // ------------------------------------------------------
        stage('Kaniko Build & Push') {
            steps {
                container('kaniko') {
                    sh """
echo "===== Kaniko Build Start: ${REGISTRY}/${IMAGE}:${TAG} ====="

cd \$WORKSPACE

/kaniko/executor \\
  --context \$WORKSPACE \\
  --dockerfile Dockerfile \\
  --destination ${REGISTRY}/${IMAGE}:${TAG} \\
  --cache=true \\
  --cache-dir=/kaniko/cache \\
  --snapshot-mode=redo
"""
                }
            }
        }

        // ------------------------------------------------------
        // 4) Deploy to Kubernetes (RollingUpdate)
        // ------------------------------------------------------
        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh """
kubectl set image deployment/${K8S_DEPLOY} \\
  ${K8S_CONTAINER}=${REGISTRY}/${IMAGE}:${TAG} \\
  -n ${K8S_NAMESPACE}

kubectl rollout status deployment/${K8S_DEPLOY} \\
  -n ${K8S_NAMESPACE} --timeout=10m
"""
                }
            }
        }
    }

    post {
        success {
            echo "SUCCESS: Build & Deploy Completed!"
        }
        failure {
            echo "FAILED: Check the Jenkins logs!"
        }
    }
}
