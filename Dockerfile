FROM openjdk:17-jdk-slim

ARG VERSION

COPY target/Deployment-${VERSION}.jar /app.jar

EXPOSE 8088

CMD ["java", "-jar", "/app.jar"]
