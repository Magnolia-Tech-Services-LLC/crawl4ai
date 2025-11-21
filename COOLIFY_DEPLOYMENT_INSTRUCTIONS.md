# Coolify Deployment Instructions for Crawl4AI

## Prerequisites

1. **Redis Service**: Deploy Redis as a separate service in Coolify (see Step 1 below)
2. **Ollama Service**: Already running in Coolify with Qwen3 14B model
3. **Git Repository**: `https://github.com/Magnolia-Tech-Services-LLC/crawl4ai.git` (fork is ready)

## Step 1: Deploy Redis Service

1. In Coolify dashboard, navigate to your project
2. Click **"+ New Resource"** → **"Database"** → **"Redis"**
3. Configure Redis:
   - **Name**: `crawl4ai-redis` (or your preferred name)
   - **Version**: Latest stable
   - **Port**: `6379` (default)
   - **Volume**: Add persistent volume at `/data` for data persistence
4. **Deploy** the Redis service
5. **Note the service name** - you'll need it for environment variables (e.g., `crawl4ai-redis`)

## Step 2: Create Crawl4AI Application

1. In your Coolify project, click **"+ New Resource"** → **"Application"**
2. **Source**: Select **"GitHub"**
3. **Repository**: `Magnolia-Tech-Services-LLC/crawl4ai`
4. **Branch**: `main`
5. **Build Pack**: `Dockerfile` (auto-detected)
6. **Destination Server**: `localhost` (wgc8cg4w08kks4s8o8scscso)
7. **Environment**: `production`

## Step 3: Configure Application Settings

### Ports
- **Exposed Port**: `11235`
- **Port Mapping**: `11235:11235`

### Environment Variables

Add the following environment variables in the application settings:

```
LLM_PROVIDER=ollama/qwen3:14b
OLLAMA_BASE_URL=http://ollama:11434
REDIS_URI=redis://crawl4ai-redis:6379/0
PYTHON_ENV=production
```

**Important Notes:**
- Replace `crawl4ai-redis` with your actual Redis service name from Step 1
- Replace `ollama` with your actual Ollama service name if different
- If Redis has a password, use: `redis://:password@crawl4ai-redis:6379/0`

### Volume Mappings

Add the following volume mapping:

| Host Path | Container Path | Description |
|-----------|----------------|-------------|
| `/dev/shm` | `/dev/shm` | Shared memory for Chromium performance |

### Resource Limits (Recommended)

- **Memory Limit**: `4096` MB (4GB)
- **Memory Reservation**: `1024` MB (1GB)
- **CPU Limit**: Leave default or set as needed

### Health Check Configuration

- **Health Check**: Enabled
- **Health Check Path**: `/health`
- **Health Check Port**: `11235`
- **Health Check Interval**: `30` seconds
- **Health Check Timeout**: `10` seconds
- **Health Check Retries**: `3`
- **Health Check Start Period**: `40` seconds

**Note**: The healthcheck in the Dockerfile checks for Redis, but since Redis is external, you may need to adjust this. The application health endpoint at `/health` should work regardless.

### Additional Settings

- **Restart Policy**: `unless-stopped`
- **Base Directory**: `/` (default)

## Step 4: Deploy and Verify

1. Click **"Save"** or **"Deploy"** to start the build
2. Monitor the build logs for any issues
3. Once deployed, verify:
   - Health endpoint: `http://your-domain:11235/health`
   - Application logs show successful Redis connection
   - Application logs show no errors

## Step 5: Verify Ollama Integration

1. Ensure Ollama service is running
2. Verify Qwen3 14B model is available:
   ```bash
   # In Ollama container or via Coolify terminal
   ollama list
   # Should show qwen3:14b
   ```
3. If model is not present, pull it:
   ```bash
   ollama pull qwen3:14b
   ```

## Step 6: Test the Application

1. Test health endpoint:
   ```bash
   curl http://your-domain:11235/health
   ```

2. Test LLM endpoint (if configured):
   ```bash
   curl -X POST http://your-domain:11235/llm/https://example.com?q=What is this page about?
   ```

## Troubleshooting

### Redis Connection Issues
- Verify Redis service name matches the `REDIS_URI` environment variable
- Check that both services are in the same Docker network
- Verify Redis is accessible: `redis-cli -h crawl4ai-redis ping`

### Ollama Connection Issues
- Verify Ollama service name in `OLLAMA_BASE_URL`
- Check network connectivity between containers
- Verify Ollama is running: `curl http://ollama:11434/api/tags`

### Health Check Failures
- The Dockerfile healthcheck includes a Redis check that may fail with external Redis
- The `/health` endpoint should still work
- Consider adjusting healthcheck if needed

## Network Configuration

Coolify automatically creates a Docker network for your project. Both the Crawl4AI application and Redis service should be in the same network to communicate. Service names are used as hostnames within the network.

## Notes

- The application uses Traefik (Coolify's default proxy), not Caddy
- Redis runs as a separate service, not inside the Crawl4AI container
- The Dockerfile includes Redis server installation for standalone deployments, but it's not used when Redis is external
- Environment variables take precedence over config.yml settings

