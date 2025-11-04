# Dockerfile
FROM mongo:6.0


# Copy configuration files (optional)
COPY ./configs /etc/mongo

# Expose MongoDB ports
EXPOSE 27017 27018 27019
