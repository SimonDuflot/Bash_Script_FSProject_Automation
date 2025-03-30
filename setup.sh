#!/bin/bash

# --- Environment Validation Section ---
# 1. First check if we're in a Linux environment
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Error: This script is designed to run in Linux environments (like your Docker container)" >&2
    echo "Please run it using: docker run -e PROJECT_DIR=your_project your-image" >&2
    exit 1
fi

# --- Version Validation Section ---
# 2. Now safely check for jq (since we're in Linux)
check_spring_boot_versions() {
    if ! command -v jq &> /dev/null; then
        echo "Warning: jq not found - skipping Spring Boot version validation" >&2
        return
    fi

    echo "Fetching valid Spring Boot versions..."
    if ! VALID_VERSIONS=$(curl -fsS https://start.spring.io/metadata/client | jq -r '.bootVersion.values[].id' | sort -Vr); then
        echo "Warning: Failed to fetch version data - skipping validation" >&2
        return
    fi

    # Actual version validation
    if ! grep -q "^$BOOT_VERSION$" <<< "$VALID_VERSIONS"; then
        echo "ERROR: Invalid Spring Boot version '$BOOT_VERSION'" >&2
        echo "Valid versions are:" >&2
        echo "$VALID_VERSIONS" >&2
        exit 1
    fi
}

OUTPUT_BASE="/output"

# Checks if env var PROJECT_DIR is specified, otherwise checks for argument, otherwise builds a my_project directory
NEW_DIR="${PROJECT_DIR:-${1:-my_project}}" 
ORIG_DIR=$(pwd)


# --- Spring Boot Configuration --- 
BOOT_VERSION="3.4.4.RELEASE"
JAVA_VERSION="17"
TYPE="maven-project"
GROUP_ID="fr.eql.ai116.duflot"
ARTIFACT_ID="backend"
SPRING_DEPS="web,data-jpa,postgresql,h2,security,validation,devtools"
TEMP_ZIP="backend-temp.zip"
PACKAGING="jar"

# Run validation using the API-specific version ID
check_spring_boot_versions

# Create the version string needed for the actual POM/artifact resolution
# This uses Bash parameter expansion: ${variable%suffix} removes shortest matching suffix
POM_BOOT_VERSION="${BOOT_VERSION%.RELEASE}"
echo "[INFO] Using Boot version for POM/API request: ${POM_BOOT_VERSION}"

# Target path for the project inside the container's output mount
PROJECT_OUTPUT_PATH="${OUTPUT_BASE}/${NEW_DIR}"

# Check if directory already exists IN THE OUTPUT PATH
if [[ -d "$PROJECT_OUTPUT_PATH" ]]; then
    echo "Error: $PROJECT_OUTPUT_PATH already exists, aborting script" >&2
    exit 1
fi

echo "Creating project structure in $PROJECT_OUTPUT_PATH..."
# Create and CD into the output path
mkdir -p "$PROJECT_OUTPUT_PATH" && cd "$PROJECT_OUTPUT_PATH" || { echo "Failed to create or enter $PROJECT_OUTPUT_PATH"; exit 1; }

# Define target dirs relative to the new current directory ($PROJECT_OUTPUT_PATH)
BACKEND_TARGET_DIR="${NEW_DIR}_back"
FRONTEND_TARGET_DIR="${NEW_DIR}_front"

mkdir "$FRONTEND_TARGET_DIR" "$BACKEND_TARGET_DIR" || {
	echo "Error: Failed to create subdirectories" >&2
    cd "$ORIG_DIR" # Go back before exiting
	exit 1;
}

echo "Success: Project directories created successfully at $(pwd)!"
ls -l

echo "Generating Spring Boot backend project (${ARTIFACT_ID})..."

BASE_URL="https://start.spring.io/starter.zip"
# Note: baseDir=${ARTIFACT_ID} explicitly sets the root folder name in the zip
PARAMS="type=${TYPE}&language=java&bootVersion=${POM_BOOT_VERSION}&baseDir=${ARTIFACT_ID}&groupId=${GROUP_ID}&artifactId=${ARTIFACT_ID}&packaging=${PACKAGING}&javaVersion=${JAVA_VERSION}&dependencies=${SPRING_DEPS}"

curl -f -L "${BASE_URL}?${PARAMS}" -o "${TEMP_ZIP}" || {
    echo "Error: Failed to download project (curl exited with error - Check parameters/URL)" >&2
	cat "${TEMP_ZIP}"
	exit 1
	}

echo "Success: generated spring boot project. Unziping file..." 

unzip -q "${TEMP_ZIP}" -d "${BACKEND_TARGET_DIR}" || {
	echo "Error: failed to unzip project" >&2
	exit 1
	}
# --- START CLEANUP SECTION ---
echo "Success: Unziped file. Cleaning up backend project..."

BACKEND_PROJECT_PATH="${BACKEND_TARGET_DIR}/${ARTIFACT_ID}"
DEMO_APP_TEST_FILE="${BACKEND_PROJECT_PATH}/src/test/java/${GROUP_ID//.//}/${ARTIFACT_ID}/DemoApplicationTests.java"

echo "[DEBUG] BACKEND_PROJECT_PATH is set to: ${BACKEND_PROJECT_PATH}" # Debug echo

# Check if the target directory exists BEFORE removing
echo "[DEBUG] Checking if .mvn exists before removal:"
ls -ld "${BACKEND_PROJECT_PATH}/.mvn"

# Remove unwanted files and directories with verbose output and error check
echo "Removing .mvn wrapper, HELP.md, .gitattributes, mvnw scripts..."
rm -rfv "${BACKEND_PROJECT_PATH}/.mvn"
rm -fv "${BACKEND_PROJECT_PATH}/.gitattributes"
rm -fv "${BACKEND_PROJECT_PATH}/HELP.md"
rm -fv "${BACKEND_PROJECT_PATH}/mvnw"
rm -fv "${BACKEND_PROJECT_PATH}/mvnw.cmd"
rm -f "${DEMO_APP_TEST_FILE}"

echo "Updating .gitignore..."

echo "# Build output folders" > "${BACKEND_PROJECT_PATH}/.gitignore"
# Append new rules
echo "target/" >> "${BACKEND_PROJECT_PATH}/.gitignore"
echo "" >> "${BACKEND_PROJECT_PATH}/.gitignore" # Add a blank line
echo "# IDE folders" >> "${BACKEND_PROJECT_PATH}/.gitignore"
echo ".idea/" >> "${BACKEND_PROJECT_PATH}/.gitignore" # IntelliJ IDEA folder
echo "*.iml" >> "${BACKEND_PROJECT_PATH}/.gitignore" # IntelliJ IDEA module file
echo "" >> "${BACKEND_PROJECT_PATH}/.gitignore"
echo "# Log files" >> "${BACKEND_PROJECT_PATH}/.gitignore"
echo "*.log" >> "${BACKEND_PROJECT_PATH}/.gitignore"
echo "Backend project cleanup complete."
# --- END CLEANUP SECTION ---
echo "Deleting temp zip file..."
rm -f "${TEMP_ZIP}"

echo "Backend project generated and cleaned in ${BACKEND_TARGET_DIR}:"
# Use ls -al to show hidden files like the updated .gitignore
ls -al "${BACKEND_PROJECT_PATH}"

echo "Adding simple TestController to backend..."

CONTROLLER_PKG_PATH="${GROUP_ID//.//}/${ARTIFACT_ID}/controller"
CONTROLLER_DIR="${BACKEND_PROJECT_PATH}/src/main/java/${CONTROLLER_PKG_PATH}"
CONTROLLER_FILE="${CONTROLLER_DIR}/TestController.java"

echo "[DEBUG] Creating controller directory: ${CONTROLLER_DIR}"
mkdir -p "${CONTROLLER_DIR}" || { echo "Error: Failed to create controller directory ${CONTROLLER_DIR}"; exit 1; }

# Create TestController.java
cat << EOF > "${CONTROLLER_FILE}"
package ${GROUP_ID}.${ARTIFACT_ID}.controller; // Use dots for package name

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.http.ResponseEntity; // Import ResponseEntity
import org.springframework.http.HttpStatus; // Import HttpStatus

@RestController
@RequestMapping("/api") // Base path for all API endpoints in this controller
@CrossOrigin(origins = "http://localhost")
public class TestController {

    @GetMapping("/test")
    public ResponseEntity<String> testEndpoint() { // Return ResponseEntity
        // Simple response with OK status
        return new ResponseEntity<>("Hello from Backend!", HttpStatus.OK);
    }
}
EOF

# Verify file creation
if [ -f "${CONTROLLER_FILE}" ]; then
    echo "TestController.java created successfully at ${CONTROLLER_FILE}"
    echo "--- TestController.java Content ---"
    cat "${CONTROLLER_FILE}"
    echo "-----------------------------------"
else
    echo "Error: Failed to create TestController.java" >&2
    exit 1
fi

# --- Add Security Configuration ---
echo "Adding basic Security Configuration..."
SECURITY_CONFIG_PKG_PATH="${GROUP_ID//.//}/${ARTIFACT_ID}/config"
SECURITY_CONFIG_DIR="${BACKEND_PROJECT_PATH}/src/main/java/${SECURITY_CONFIG_PKG_PATH}"
SECURITY_CONFIG_FILE="${SECURITY_CONFIG_DIR}/SecurityConfig.java"

mkdir -p "${SECURITY_CONFIG_DIR}" || { echo "Error: Failed to create security config directory"; exit 1; }

cat << EOF > "${SECURITY_CONFIG_FILE}"
package ${GROUP_ID}.${ARTIFACT_ID}.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.web.SecurityFilterChain;
import static org.springframework.security.config.Customizer.withDefaults;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(authorizeRequests ->
                authorizeRequests
                    .requestMatchers("/api/test").permitAll() // Permit access to /api/test
                    .anyRequest().authenticated() // Require auth for all other requests
            )
            .httpBasic(withDefaults()); // Enable basic auth for other requests (or use formLogin etc.)
        return http.build();
    }
    // Add other beans like PasswordEncoder, UserDetailsService later if needed
}
EOF
# Verification...
if [ -f "${SECURITY_CONFIG_FILE}" ]; then
    echo "SecurityConfig.java created successfully at ${SECURITY_CONFIG_FILE}"
    echo "--- TestControllerIntegrationTest.java Content ---"
    cat "${SECURITY_CONFIG_FILE}"
    echo "-----------------------------------"
else
    echo "Error: Failed to create SecurityConfig.java" >&2
    exit 1
fi

# --- End Security Configuration ---

echo "Adding integration test for TestController..."

# Define test controller directory path
TEST_CONTROLLER_PKG_PATH="${GROUP_ID//.//}/${ARTIFACT_ID}/controller"
TEST_CONTROLLER_DIR="${BACKEND_PROJECT_PATH}/src/test/java/${TEST_CONTROLLER_PKG_PATH}"
TEST_CONTROLLER_FILE="${TEST_CONTROLLER_DIR}/TestControllerIntegrationTest.java"

# Create the test package directories if they don't exist
echo "[DEBUG] Creating test controller directory: ${TEST_CONTROLLER_DIR}"
mkdir -p "${TEST_CONTROLLER_DIR}" || { echo "Error: Failed to create test controller directory ${TEST_CONTROLLER_DIR}"; exit 1; }

# Create TestControllerIntegrationTest.java
cat << EOF > "${TEST_CONTROLLER_FILE}"
package ${GROUP_ID}.${ARTIFACT_ID}.controller; // Use dots for package name

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest // Loads the full application context for the test
@AutoConfigureMockMvc // Auto-configures MockMvc for web layer testing
@ActiveProfiles("test") // Ensures the 'test' profile (using H2) is active
class TestControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc; // Injects MockMvc instance

    @Test
    void testTestEndpoint() throws Exception {
        mockMvc.perform(get("/api/test")) // Perform GET request to the endpoint
               .andExpect(status().isOk()) // Assert HTTP status is 200 OK
               .andExpect(content().string("Hello from Backend!")); // Assert response body matches
    }
}
EOF
# Verify file creation
if [ -f "${TEST_CONTROLLER_FILE}" ]; then
    echo "TestControllerIntegrationTest.java created successfully at ${TEST_CONTROLLER_FILE}"
    echo "--- TestControllerIntegrationTest.java Content ---"
    cat "${TEST_CONTROLLER_FILE}"
    echo "-----------------------------------"
else
    echo "Error: Failed to create TestController.java" >&2
    exit 1
fi

# Create base application.properties
cat << EOF > "${BACKEND_PROJECT_PATH}/src/main/resources/application.properties"
server.port=8080
spring.application.name=backend
# Default profile if not set externally
spring.profiles.active=\${SPRING_PROFILES_ACTIVE:dev}
# Common JPA/Hibernate settings
spring.jpa.open-in-view=false
spring.jpa.properties.hibernate.jdbc.lob.non_contextual_creation=true
# Basic logging setup
logging.level.root=INFO
logging.level.fr.eql.ai116.duflot=DEBUG
EOF
# Verify file creation
if [ -f "${BACKEND_PROJECT_PATH}/src/main/resources/application.properties" ]; then
    echo "application.properties created successfully at ${BACKEND_PROJECT_PATH}/src/main/resources/application.properties"
    echo "--- application.properties Content ---"
    cat "${BACKEND_PROJECT_PATH}/src/main/resources/application.properties"
    echo "-----------------------------------"
else
    echo "Error: Failed to create application.properties in ${BACKEND_PROJECT_PATH}/src/main/resources" >&2
    exit 1
fi

# Create application-test.properties
cat <<EOL > "${BACKEND_PROJECT_PATH}/src/main/resources/application-test.properties"
# --- H2 Database (Test) ---
spring.datasource.url=jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=
spring.datasource.password=
spring.jpa.database-platform=org.hibernate.dialect.H2Dialect
# Create/Drop DB schema automatically for each test run
spring.jpa.hibernate.ddl-auto=create-drop

# Keep test logs clean
spring.jpa.show-sql=false

# No console needed for tests
spring.h2.console.enabled=false
EOL
# Verify file creation
if [ -f "${BACKEND_PROJECT_PATH}/src/main/resources/application-test.properties" ]; then
    echo "application-test.properties created successfully at ${BACKEND_PROJECT_PATH}/src/main/resources/application-test.properties"
    echo "--- application-test.properties Content ---"
    cat "${BACKEND_PROJECT_PATH}/src/main/resources/application-test.properties"
    echo "-----------------------------------"
else
    echo "Error: Failed to create application-test.properties in ${BACKEND_PROJECT_PATH}/src/main/resources" >&2
    exit 1
fi

# Create application-dev.properties
cat <<EOL > "${BACKEND_PROJECT_PATH}/src/main/resources/application-dev.properties"
# --- PostgreSQL Database (Dev) ---
# Connects to local Postgres (likely running in Docker later)
# Defaults assume Docker Compose setup: host='localhost', port=5432, db='devdb', user='devuser', pass='devpass'
spring.datasource.url=jdbc:postgresql://\${DB_HOST:postgres}:\${DB_PORT:5432}/\${POSTGRES_DB:devdb}
spring.datasource.username=\${POSTGRES_USER:devuser}
spring.datasource.password=\${POSTGRES_PASSWORD:devpass}
spring.datasource.driverClassName=org.postgresql.Driver
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect
# Allow Hibernate to update schema in dev for convenience (use with caution)
spring.jpa.hibernate.ddl-auto=update

# Show SQL in dev logs
spring.jpa.show-sql=true 
spring.jpa.properties.hibernate.default_schema=public
# Or your dev schema
EOL
# Verify file creation
if [ -f "${BACKEND_PROJECT_PATH}/src/main/resources/application-dev.properties" ]; then
    echo "application-dev.properties created successfully at ${BACKEND_PROJECT_PATH}/src/main/resources/application-dev.properties"
    echo "--- application-dev.properties Content ---"
    cat "${BACKEND_PROJECT_PATH}/src/main/resources/application-dev.properties"
    echo "-----------------------------------"
else
    echo "Error: Failed to create application-dev.properties in ${BACKEND_PROJECT_PATH}/src/main/resources" >&2
    exit 1
fi

# Create application-prod.properties
cat <<EOL > "${BACKEND_PROJECT_PATH}/src/main/resources/application-prod.properties"
# --- PostgreSQL Database (Prod) ---
# Values MUST be injected by environment variables in production
spring.datasource.url=jdbc:postgresql://\${DB_HOST:postgres}:\${DB_PORT:5432}/\${POSTGRES_DB}
spring.datasource.username=\${POSTGRES_USER}
spring.datasource.password=\${POSTGRES_PASSWORD}
spring.datasource.driverClassName=org.postgresql.Driver
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect
# IMPORTANT: Use 'validate' or 'none' in production. Schema managed externally.
spring.jpa.hibernate.ddl-auto=validate
spring.jpa.show-sql=false # Keep prod logs cleaner
# Or your prod schema
spring.jpa.properties.hibernate.default_schema=public 
# Ensure schema.sql/data.sql are never used
spring.sql.init.mode=NEVER 

EOL
# Verify file creation
if [ -f "${BACKEND_PROJECT_PATH}/src/main/resources/application-prod.properties" ]; then
    echo "application-prod.properties created successfully at ${BACKEND_PROJECT_PATH}/src/main/resources/application-prod.properties"
    echo "--- application-prod.properties Content ---"
    cat "${BACKEND_PROJECT_PATH}/src/main/resources/application-prod.properties"
    echo "-----------------------------------"
else
    echo "Error: Failed to create application-prod.properties in ${BACKEND_PROJECT_PATH}/src/main/resources" >&2
    exit 1
fi
# List newly created files
ls -l "${BACKEND_PROJECT_PATH}/src/main/resources"

# Setup Dockerfile
echo "Creating Dockerfile for the backend application..."
BACKEND_DOCKERFILE="${BACKEND_PROJECT_PATH}/Dockerfile"

cat << EOF > "${BACKEND_DOCKERFILE}"
# Stage 1: Build the application using Maven
# Use a specific Maven image with the correct Java version
FROM maven:3.9-eclipse-temurin-${JAVA_VERSION}-alpine AS builder

WORKDIR /app

# Copy pom.xml first to leverage Docker cache for dependencies
COPY pom.xml .
# Download all dependencies
RUN mvn dependency:go-offline -B

# Copy the rest of the source code
COPY src ./src

# Package the application, skipping tests (tests will run in CI/locally)
RUN mvn package -DskipTests -B

# Stage 2: Create the final lightweight runtime image
# Use a JRE image matching the Java version, preferably slim or alpine
FROM eclipse-temurin:${JAVA_VERSION}-jre-alpine

WORKDIR /app

# Copy the packaged JAR file from the build stage
# Use wildcard to copy the jar without knowing the exact version in the name
COPY --from=builder /app/target/*.jar app.jar

# Expose the port the application runs on
EXPOSE 8080

# Command to run the application
# Use exec form for better signal handling
ENTRYPOINT ["java", "-Xmx512m", "-jar", "/app/app.jar"]

# Optional: Add healthcheck instruction if needed later
# HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 CMD curl -f http://localhost:8080/actuator/health || exit 1
EOF
# Verify file creation
if [ -f "${BACKEND_DOCKERFILE}" ]; then
    echo "Backend Dockerfile created successfully at ${BACKEND_DOCKERFILE}"
else
    echo "Error: Failed to create backend Dockerfile" >&2
    exit 1
fi
#List files in root
ls -l "${BACKEND_PROJECT_PATH}"

echo "Creating basic frontend files in ${FRONTEND_TARGET_DIR}..."

# Create index.html
cat << EOF > "${FRONTEND_TARGET_DIR}/index.html"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${NEW_DIR}</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <h1>Welcome to ${NEW_DIR}!</h1>
    <p>Frontend is working.</p>
	<div class="container">
        <h2>Test de connexion à l'API</h2>
        <p>Cliquez sur le bouton ci-dessous pour vérifier que l'API est accessible :</p>
        <button id="test-api">Tester l'API</button>
        <div id="api-result">Le résultat apparaîtra ici...</div>
    </div>
    <script src="script.js"></script>
</body>
</html>
EOF

# Create style.css
cat << EOF > "${FRONTEND_TARGET_DIR}/style.css"
body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            color: #cc0000;
            text-align: center;
        }
        .container {
            margin-top: 30px;
        }
        button {
            background-color: #cc0000;
            color: white;
            border: none;
            padding: 10px 15px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background-color: #990000;
        }
        #api-result {
            margin-top: 20px;
            padding: 15px;
            border: 1px solid #ddd;
            border-radius: 4px;
            min-height: 50px;
            background-color: #f9f9f9;
        }
EOF

# Create script.js
cat <<EOF > "${FRONTEND_TARGET_DIR}/script.js"
document.addEventListener('DOMContentLoaded', function() {
    
    const testButton = document.getElementById('test-api');
    const resultDiv = document.getElementById('api-result');
    
    testButton.addEventListener('click', async function() {
        try {
            const response = await fetch('http://localhost:8080/api/test');
            const data = await response.text();
            resultDiv.textContent = data;
        } catch (error) {
            resultDiv.textContent = "Erreur de connexion à l'API: " + error.message;
        }
    });
});
EOF

echo "Frontend placeholder files created."
ls -l "${FRONTEND_TARGET_DIR}" # Show the created frontend files

echo "Creating Dockerfile for the frontend application..."
FRONTEND_DOCKERFILE="${FRONTEND_TARGET_DIR}/Dockerfile"
cat << EOF > "${FRONTEND_DOCKERFILE}"
FROM nginx:stable-alpine
RUN rm -f /usr/share/nginx/html/index.html /user/share/nginx/html/50x.html
COPY . /usr/share/nginx/html/
EXPOSE 80
EOF
# Verify file creation
if [ -f "${FRONTEND_DOCKERFILE}" ]; then
    echo "Frontend Dockerfile created successfully at ${FRONTEND_DOCKERFILE}"
else
    echo "Error: Failed to create frontend Dockerfile" >&2
    exit 1
fi

echo "Creating docker-compose.yml in project root..."
cat << EOF > "docker-compose.yml" # Create in current directory ($NEW_DIR)
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: \${COMPOSE_PROJECT_NAME:-${NEW_DIR}}_db # Use project name prefix
    environment:
      POSTGRES_DB: \${POSTGRES_DB:-devdb} # Default DB name for dev
      POSTGRES_USER: \${POSTGRES_USER:-devuser} # Default user for dev
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-devpass} # Default pass for dev
    volumes:
      - postgres_data:/var/lib/postgresql/data # Persist data using named volume
    networks:
      - app-network
    # ports: # Only expose ports if needed for direct external access/debugging
      # - "5432:5432"
    healthcheck: # Basic check to see if Postgres is ready to accept commands
        test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER:-devuser} -d \${POSTGRES_DB:-devdb}"]
        interval: 10s
        timeout: 5s
        retries: 5

  backend:
    container_name: \${COMPOSE_PROJECT_NAME:-${NEW_DIR}}_backend
    build:
      context: ./${BACKEND_TARGET_DIR}/${ARTIFACT_ID} # Path to backend project containing Dockerfile
      dockerfile: Dockerfile
    depends_on:
      db: # Wait for db service to start and ideally be healthy
        condition: service_healthy
    environment:
      # Activate the 'prod' profile (uses Postgres via env vars below)
      # OR use 'dev' profile if you want docker-compose up to use dev settings
      SPRING_PROFILES_ACTIVE: prod
      # --- These match the prod profile properties ---
      DB_HOST: db # Service name of the database container
      DB_PORT: 5432
      POSTGRES_DB: \${POSTGRES_DB:-devdb} # Match db service env var
      POSTGRES_USER: \${POSTGRES_USER:-devuser} # Match db service env var
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-devpass} # Match db service env var
      # --- Other backend env vars if needed ---
    ports:
      - "8080:8080" # Map host port 8080 to container port 8080
    networks:
      - app-network

  frontend:
    container_name: \${COMPOSE_PROJECT_NAME:-${NEW_DIR}}_frontend
    build:
      context: ./${FRONTEND_TARGET_DIR} # Path to frontend project containing Dockerfile
      dockerfile: Dockerfile
    ports:
      - "80:80" # Map host port 80 to container port 80
    networks:
      - app-network
    # depends_on: # Frontend doesn't strictly depend on backend start for static files
      # - backend

networks:
  app-network:
    driver: bridge

volumes:
  postgres_data: # Define the named volume used by the db service
    driver: local
EOF

# Verify file creation
if [ -f "docker-compose.yml" ]; then
    echo "docker-compose.yml created successfully in $(pwd)"
else
    echo "Error: Failed to create docker-compose.yml" >&2
    exit 1
fi

# --- Adjust script.js to use full URL ---
echo "Adjusting frontend script.js to use absolute URL for API call..."
FRONTEND_SCRIPT_FILE="${FRONTEND_TARGET_DIR}/script.js"
sed -i.bak "s|fetch('/api/test')|fetch('http://localhost:8080/api/test')|g" "${FRONTEND_SCRIPT_FILE}" && rm -f "${FRONTEND_SCRIPT_FILE}.bak" || {
    echo "Error: Failed to update script.js fetch URL" >&2 
}
echo "Frontend script.js adjusted."



# --- Final Steps ---
cd "$ORIG_DIR" || exit
echo "Success: Project setup complete in $(pwd)!"

