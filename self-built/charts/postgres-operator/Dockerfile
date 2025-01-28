FROM python:3.10-slim

# Set the working directory
WORKDIR /app

# Install necessary system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  gcc=4:12.2.0-3 \
  libpq-dev=15.10-0+deb12u1 \
  && rm -rf /var/lib/apt/lists/*

# Copy the operator script and requirements
COPY requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY operator.py /app/operator.py

# Set the entrypoint to dynamically resolve environment variables
ENTRYPOINT ["sh", "-c"]

# Command to run the operator
CMD ["exec kopf run --namespace=${WATCH_NAMESPACE} /app/operator.py"]

