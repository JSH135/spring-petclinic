FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Jenkins 빌드 결과물 JAR 복사
COPY target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
