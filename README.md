# Full Stack Project Scaffolding Script (`setup.sh`)

This script automates the creation of a boilerplate full-stack project structure, including:

*   A Vanilla JS frontend (`_front` directory)
*   A Spring Boot backend (`_back` directory) with Maven, configured with common dependencies (Web, JPA, Security, Validation, DevTools, PostgreSQL, H2).
*   Basic API endpoint (`/api/test`) and corresponding integration test.
*   Spring Profile configuration (`dev`, `test`, `prod`).
*   Dockerfiles for both frontend and backend.
*   A `docker-compose.yml` file to run the entire stack (Frontend, Backend, PostgreSQL DB).

## Prerequisites

*   [Docker](https://docs.docker.com/get-docker/) must be installed and running on your system.
*   An internet connection is required during script execution to download dependencies.

## Usage: Generating the Project

This script is designed to be run inside a dedicated Docker container to ensure a consistent environment. The generated project files will be placed in an `output` directory in the location where you run the commands.

1.  **Build the Script Runner Docker Image:**
    Open your terminal in the directory containing `setup.sh` and `Dockerfile`. Run:
    ```bash
    docker build -t setup-test .
    ```
    *(This creates an image named `setup-test` containing the script and its dependencies like `curl`, `unzip`, `jq`.)*

2.  **Create Local Output Directory:**
    Before running the script, create a directory named `output` where the generated project will be placed:
    ```bash
    # On Linux/macOS/Git Bash/WSL
    mkdir output

    # On Windows Command Prompt
    mkdir output

    # On Windows PowerShell, use 'pwsh' to change instance (C --> PS)
    pwsh 
    New-Item -ItemType Directory -Force -Path "./output"
    ```

3.  **Run the Script via Docker Container:**
    Execute the following command. This runs the `setup.sh` script inside the container and mounts your local `output` directory to `/output` inside the container, so the generated files appear locally.

    *   **On Linux/macOS/Git Bash/WSL:**
        ```bash
        docker run --rm -v "$(pwd)/output:/output" setup-test
        ```
    *   **On Windows PowerShell:**
        ```powershell
        docker run --rm -v "${PWD}/output:/output" setup-test
        ```
    *   **On Windows Command Prompt:**
        ```cmd
        docker run --rm -v "%cd%/output:/output" setup-test
        ```

    *   **(Optional) Custom Project Name:** You can specify a different project name using the `PROJECT_DIR` environment variable:
        ```bash
        # Example for PowerShell:
        docker run --rm -e PROJECT_DIR=my_cool_app -v "${PWD}/output:/output" setup-test
        ```

    Upon successful completion, you will find your generated project inside the `output` directory (e.g., `output/my_project`).

## Testing the Generated Project

After the script finishes, you can perform initial tests on the generated project:

1.  **Navigate to Project:**
    ```bash
    cd output/my_project
    ```
    *(Replace `my_project` if you used a custom name)*

2.  **Run Backend Integration Tests:**
    This verifies the basic Spring Boot context loading and the `/api/test` endpoint using the H2 database profile.
    *   Navigate to the backend directory:
        ```bash
        cd my_project_back/backend
        ```
        *(Adjust `my_project_back` if needed)*
    *   Make sure you have a compatible JDK (Java 17+) and Maven installed locally.
    *   Run the tests:
        ```bash
        mvn test
        ```
    *   Look for a `BUILD SUCCESS` message.

## Running the Full Application (Docker Compose)

To run the complete application stack (PostgreSQL DB, Backend, Frontend) locally using Docker Compose:

1.  **Navigate to Project Root:**
    Make sure you are in the main generated project directory (e.g., `output/my_project`).
    ```bash
    # If you are in the backend directory from the previous step:
    cd ../..
    ```

2.  **Ensure Docker is Running.**

3.  **Build and Start Services:**
    ```bash
    docker-compose up --build
    ```
    *   This command builds the frontend and backend images (if not already built) and starts the database, backend, and frontend containers.
    *   Wait for the logs to show the database is ready and the backend has started (look for "Started BackendApplication...").

4.  **Access the Application:**
    *   Open your web browser and go to `http://localhost` (or `http://localhost:80`). You should see the frontend welcome page.
    *   Click the "Tester l'API" button. The text below should update to "Hello from Backend!". You can check the browser's network console (F12) to see the successful request to `http://localhost:8080/api/test`.

5.  **Stop the Application:**
    *   Press `Ctrl+C` in the terminal where `docker-compose up` is running.
    *   To remove the containers and network (but keep the database data volume), run:
        ```bash
        docker-compose down
        ```
    *   To remove containers, network, *and* the database volume (for a completely clean state), run:
        ```bash
        docker-compose down -v
        ```
