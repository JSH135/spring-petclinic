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

  #hostNetwork: true
  #dnsPolicy: ClusterFirstWithHostNet

  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
    - key: "node.kubernetes.io/disk-pressure"
      operator: "Exists"
      effect: "NoSchedule"

  containers:
    # --------------------------------------
    # Kaniko Container
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
    # Maven Container
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
    # Kubectl Container
    # --------------------------------------
    - name: kubectl
      image: leeplayed/kubectl:1.28
      tty: true
      command: ["/bin/sh"]
      args: ["-c", "sleep infinity"]
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
    - name: docker-config
      secret:
        secretName: dockertoken
        items:
        - key: ".dockerconfigjson"
          path: config.json

    - name: workspace-volume
      emptyDir: {}

    - name: maven-cache
      emptyDir: {}

    - name: kaniko-cache
      emptyDir: {}
"""
        }
    }

    environment {
        REGISTRY      = "docker.io/josohyun"
        IMAGE         = "spring-petclinic"
        TAG           = "${BUILD_NUMBER}"
        K8S_NAMESPACE = "petclinic"
        K8S_DEPLOY    = "petclinic"
        K8S_CONTAINER = "petclinic"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/JSH135/spring-petclinic.git'
            }
        }

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

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh """
kubectl set image deployment/${K8S_DEPLOY} \\
  ${K8S_CONTAINER}=${REGISTRY}/${IMAGE}:${TAG} \\
  -n ${K8S_NAMESPACE}

# kubectl rollout status deployment/${K8S_DEPLOY} \\
#   -n ${K8S_NAMESPACE} --timeout=10m
# 롤아웃 대기 (10분까지 기다리고, 실패해도 로그만 찍고 계속)
if ! kubectl rollout status deployment/${K8S_DEPLOY} \\
  -n ${K8S_NAMESPACE} --timeout=10m; then
  echo "[WARN] Rollout timeout, current status:"
  kubectl get pods -n ${K8S_NAMESPACE} -o wide
fi
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

