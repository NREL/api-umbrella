# Include Ubuntu LTS
FROM ubuntu:latest

# Update APT
RUN apt-get update

# Install wget
RUN apt-get install -y wget

# Get API Umbrella package
RUN wget https://developer.nrel.gov/downloads/api-umbrella/ubuntu/14.04/api-umbrella_0.8.0-1_amd64.deb

# Install GCC
RUN apt-get install -y gcc

# Install API Umbrella
RUN dpkg -i api-umbrella_0.8.0-1_amd64.deb

# Copy the docker entrypoint script to root
COPY docker-entrypoint.sh /

# Run the entrypoint script
ENTRYPOINT ["/docker-entrypoint.sh"]

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Run the API Umbrella service
CMD ["api-umbrella", "run"]
