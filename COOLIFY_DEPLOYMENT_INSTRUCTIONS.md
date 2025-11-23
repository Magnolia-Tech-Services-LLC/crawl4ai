# Coolify Deployment Instructions for Crawl4AI

## Prerequisites

1. **Ollama Service**: Already running in Coolify with Qwen3 14B model
2. **Git Repository**: `https://github.com/Magnolia-Tech-Services-LLC/crawl4ai.git` (fork is ready)
3. **Docker Compose**: The repository includes `docker-compose.yml` with Redis service included

## Step 1: Create Crawl4AI Application with Docker Compose

1. In your Coolify project, click **"+ New Resource"** → **"Application"**
2. **Source**: Select **"GitHub"**
3. **Repository**: `Magnolia-Tech-Services-LLC/crawl4ai`
4. **Branch**: `main`
5. **Build Pack**: Select **"Docker Compose"** (not Dockerfile)
6. **Docker Compose Location**: `/docker-compose.yml` (root of repository)
7. **Base Directory**: `/` (root)
8. **Destination Server**: `localhost` (wgc8cg4w08kks4s8o8scscso)
9. **Environment**: `production`

## Step 2: Configure Environment Variables

### Required Environment Variables

Add the following **required** environment variables in the application settings:

```
LLM_PROVIDER=ollama/qwen3:14b
```

### Optional Environment Variables

Add these if needed:

```
OLLAMA_API_BASE=http://ollama:11434
```

**When to set OLLAMA_API_BASE:**
- Only needed if Ollama is on a different host/network than the default
- If Ollama service name in Coolify is different from `ollama`
- If Ollama uses a non-standard port
- If Ollama is accessible via a different URL

**If not set:** LiteLLM will use the default Ollama endpoint (`http://localhost:11434`), which works if Ollama is in the same container or accessible via service name.

**Important:** According to official LiteLLM documentation, the environment variable must be `OLLAMA_API_BASE` (not `OLLAMA_BASE_URL`). LiteLLM automatically checks this environment variable when using Ollama providers.

### Automatically Configured (No Action Needed)

These are set automatically by docker-compose.yml:
- `REDIS_URI=redis://redis:6379/0` - Redis connection
- `PYTHON_ENV=production` - Already set in Dockerfile

### Additional Optional Variables

You can optionally set these for advanced configuration:

```
LLM_TEMPERATURE=0.7                    # Global LLM temperature (0.0-2.0)
RATE_LIMITING_STORAGE_URI=redis://... # Override rate limiting storage (defaults to Redis if REDIS_URI set)
```

**Important Notes:**
- `REDIS_URI` is automatically set to `redis://redis:6379/0` by docker-compose.yml
- Replace `ollama` with your actual Ollama service name if different
- The Redis service is included in the docker-compose.yml and will be deployed automatically

### Docker Compose Configuration

The `docker-compose.yml` file includes:
- **crawl4ai service**: Main application on port 11235
- **redis service**: Redis 7 Alpine with persistent volume at `/data`
- **Network**: Both services on `crawl4ai-network`
- **Volume**: `redis_data` for Redis persistence

The compose file automatically:
- Sets `REDIS_URI=redis://redis:6379/0` for the crawl4ai service
- Configures Redis with AOF persistence (`--appendonly yes`)
- Sets up health checks for both services
- Configures service dependencies (crawl4ai waits for Redis to be healthy)

### Volume Mappings (if needed)

The docker-compose.yml already includes:
- `/dev/shm:/dev/shm` for Chromium performance (in base config)
- `redis_data:/data` for Redis persistence (managed by compose)

If you need additional volumes, add them in Coolify's volume settings.

### Resource Limits

Resource limits are defined in docker-compose.yml:
- **Memory Limit**: `4096` MB (4GB) for crawl4ai
- **Memory Reservation**: `1024` MB (1GB) for crawl4ai
- Redis uses default limits (adjust if needed in compose file)

### Additional Settings

- **Restart Policy**: `unless-stopped`
- **Base Directory**: `/` (default)

## Step 3: Deploy and Verify

1. Click **"Save"** or **"Deploy"** to start the build
2. Coolify will:
   - Build the crawl4ai image from Dockerfile
   - Pull the Redis image
   - Create the network and volumes
   - Start both services
3. Monitor the build logs for any issues
4. Once deployed, verify:
   - Both `crawl4ai` and `redis` services are running
   - Health endpoint: `http://your-domain:11235/health`
   - Application logs show successful Redis connection to `redis:6379`
   - Redis logs show it's running and healthy

## Step 4: Verify Ollama Integration

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

## Step 5: Test the Application

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
- Verify both `crawl4ai` and `redis` services are running in Coolify
- Check that both services are in the same Docker network (`crawl4ai-network`)
- Verify Redis is accessible from crawl4ai container: `docker exec <crawl4ai-container> redis-cli -h redis ping`
- Check Redis logs in Coolify for any errors
- Verify `REDIS_URI` environment variable is set correctly (should be `redis://redis:6379/0` from compose)

### Ollama Connection Issues
- Verify Ollama service name in `OLLAMA_API_BASE`
- Check network connectivity between containers
- Verify Ollama is running: `curl http://ollama:11434/api/tags`

### Gateway Timeout (504) Issues
- **Root Cause**: Traefik (Coolify's reverse proxy) has a default timeout (usually 60 seconds) that's shorter than LLM processing time for large models
- **Solution 1**: Increase Traefik timeout in Coolify:
  1. Go to your application settings in Coolify
  2. Look for "Traefik Labels" or "Advanced Settings"
  3. Add label: `traefik.http.services.crawl4ai.loadbalancer.server.healthcheck.timeout=300s`
  4. Or add to docker-compose.yml under labels:
     ```yaml
     labels:
       - "traefik.http.middlewares.crawl4ai-timeout.forwardauth.address=http://localhost:11235"
       - "traefik.http.services.crawl4ai.loadbalancer.healthcheck.timeout=300s"
     ```
- **Solution 2**: Use a smaller/faster model (e.g., `ollama/qwen3:4b` instead of `qwen3:14b`)
- **Solution 3**: Consider using streaming responses for long-running requests
- **Note**: Large models like qwen3:14b (14.8B parameters) can take 60-120+ seconds to respond on CPU

### Health Check Failures
- The Dockerfile healthcheck includes a Redis check that may fail with external Redis
- The `/health` endpoint should still work
- Consider adjusting healthcheck if needed

## Network Configuration

Coolify automatically creates a Docker network for your project. Both the Crawl4AI application and Redis service should be in the same network to communicate. Service names are used as hostnames within the network.

## Notes

- The application uses Traefik (Coolify's default proxy), not Caddy
- Redis runs as a separate service defined in docker-compose.yml
- The Dockerfile includes Redis server installation for standalone deployments, but supervisord skips starting it when `REDIS_URI` is set
- Environment variables take precedence over config.yml settings
- Docker Compose automatically manages the network, volumes, and service dependencies
- Redis data persists in the `redis_data` volume across container restarts
- For standalone deployments (without docker-compose), Redis runs inside the container via supervisord

