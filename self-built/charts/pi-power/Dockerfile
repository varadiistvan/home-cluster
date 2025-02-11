FROM dtcooper/raspberrypi-os:python3.9

# Set the working directory
WORKDIR /app

# Copy the Python script to the container
COPY server.py /app/server.py

# Expose the port used by the server
EXPOSE 9101

# Run the server
CMD ["python3", "/app/server.py"]
