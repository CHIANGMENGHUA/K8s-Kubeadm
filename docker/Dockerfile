# Use Eclipse Temurin OpenJDK 21 runtime as base image
FROM eclipse-temurin:21-jre

# Set working directory
WORKDIR /app

# Copy the JAR file to the container
COPY batch-processing-demo-0.0.1-SNAPSHOT.jar app.jar

# Create a non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose port 9191 (default Spring Boot port)
EXPOSE 9191

# Set JVM options for production
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseG1GC -XX:+UseContainerSupport"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:9191/actuator/health || exit 1

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]