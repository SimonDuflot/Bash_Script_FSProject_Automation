FROM ubuntu:22.04

ENV PROJECT_DIR=""

# Update package lists and install dependencies
RUN apt-get update -q && \
	apt-get install -yq --no-install-recommends \
		curl \
		unzip \
		ca-certificates \
		jq \
		# Add any other tools your setup.sh might need in the future

		# Chains commands together. The whole RUN instruction fails if any part fails.
		&& rm -rf /var/lib/apt/lists/*
		# Cleans up the package lists cache after installation, further reducing image size.
		

# Set the working directory inside the container
WORKDIR /app

# Copy the setup script from the build context into the container's working directory
COPY setup.sh /app/

# Make the script executable
RUN chmod +x /app/setup.sh

# Set the default command to run when the container starts
CMD ["/app/setup.sh"]


