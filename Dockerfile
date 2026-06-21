FROM python:3.12-slim

WORKDIR /app

# Install system deps for MySQL + audio processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    default-libmysqlclient-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY backend/app ./app
COPY frontend ./frontend
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Ensure uploads directory exists
RUN mkdir -p uploads

EXPOSE 8000

ENTRYPOINT ["/docker-entrypoint.sh"]
