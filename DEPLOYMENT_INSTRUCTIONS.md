# Studio Lite Production Deployment Instructions

## Prerequisites
- Docker installed on Ubuntu VM
- Access to ghcr.io/tesslateai/designer container registry
- PostgreSQL database (can be external or containerized)
- LiteLLM proxy server (can be external or containerized)

## 1. Create Environment File

Create a `.env.production` file on your Ubuntu server with the following variables:

```bash
# Database Configuration
POSTGRES_URL=postgresql://YOUR_DB_USER:YOUR_DB_PASSWORD@YOUR_DB_HOST:5432/YOUR_DB_NAME

# Firebase Configuration (for authentication)
FIREBASE_SERVICE_ACCOUNT={"YOUR_FIREBASE_SERVICE_ACCOUNT_JSON"}

# Public Firebase Configuration
NEXT_PUBLIC_FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=YOUR_PROJECT.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=YOUR_PROJECT.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID
NEXT_PUBLIC_FIREBASE_APP_ID=YOUR_APP_ID

# Stripe Configuration
STRIPE_SECRET_KEY=sk_live_YOUR_STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET
STRIPE_PLUS_PRICE_ID=price_YOUR_PLUS_PRICE_ID
STRIPE_PRO_PRICE_ID=price_YOUR_PRO_PRICE_ID

# LiteLLM Configuration
LITELLM_PROXY_URL=https://YOUR_LITELLM_URL
LITELLM_MASTER_KEY=sk-YOUR_LITELLM_MASTER_KEY

# Application URLs
BASE_URL=https://designer.tesslate.com
NEXT_PUBLIC_BASE_URL=https://designer.tesslate.com

# Node Environment
NODE_ENV=production
```

## 2. Pull the Container Image

```bash
# Login to GitHub Container Registry (if private)
docker login ghcr.io -u USERNAME

# Pull the latest image
docker pull ghcr.io/tesslateai/designer:latest

# Or pull a specific version
docker pull ghcr.io/tesslateai/designer:6c62053
```

## 3. Run the Container

### Option A: Simple Docker Run

```bash
docker run -d \
  --name studio-lite \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file .env.production \
  ghcr.io/tesslateai/designer:latest
```

### Option B: Docker Compose (Recommended)

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  studio-lite:
    image: ghcr.io/tesslateai/designer:latest
    container_name: studio-lite
    restart: unless-stopped
    ports:
      - "3000:3000"
    env_file:
      - .env.production
    networks:
      - studio-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Optional: PostgreSQL database
  postgres:
    image: postgres:16-alpine
    container_name: studio-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: studio_db
      POSTGRES_USER: studio_user
      POSTGRES_PASSWORD: YOUR_SECURE_PASSWORD
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - studio-network

  # Optional: LiteLLM Proxy
  litellm-proxy:
    image: ghcr.io/berriai/litellm:main-stable
    container_name: litellm-proxy
    restart: unless-stopped
    environment:
      LITELLM_MASTER_KEY: YOUR_LITELLM_MASTER_KEY
      DATABASE_URL: postgresql://litellm_user:YOUR_PASSWORD@postgres-litellm:5432/litellm_db
    volumes:
      - ./litellm-config.yaml:/app/config.yaml
    command: ["--config", "/app/config.yaml", "--host", "0.0.0.0", "--port", "4000"]
    networks:
      - studio-network

networks:
  studio-network:
    driver: bridge

volumes:
  postgres-data:
```

Then run:
```bash
docker-compose up -d
```

## 4. Nginx Reverse Proxy (Optional but Recommended)

Install Nginx and create `/etc/nginx/sites-available/studio-lite`:

```nginx
server {
    listen 80;
    server_name designer.tesslate.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name designer.tesslate.com;

    ssl_certificate /etc/letsencrypt/live/designer.tesslate.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/designer.tesslate.com/privkey.pem;

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/studio-lite /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 5. SSL Certificate (with Let's Encrypt)

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d designer.tesslate.com
```

## 6. Database Migrations

Run migrations before starting the application:

```bash
docker run --rm \
  --env-file .env.production \
  ghcr.io/tesslateai/designer:latest \
  node lib/db/setup.js
```

## 7. Monitoring and Logs

View container logs:
```bash
docker logs -f studio-lite
```

Monitor container status:
```bash
docker ps
docker stats studio-lite
```

## 8. Updating the Application

```bash
# Pull the latest image
docker pull ghcr.io/tesslateai/designer:latest

# Stop and remove the old container
docker stop studio-lite
docker rm studio-lite

# Start with the new image
docker run -d \
  --name studio-lite \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file .env.production \
  ghcr.io/tesslateai/designer:latest
```

## 9. Backup Strategy

### Database Backup
```bash
# Create backup
docker exec studio-postgres pg_dump -U studio_user studio_db > backup_$(date +%Y%m%d).sql

# Restore backup
docker exec -i studio-postgres psql -U studio_user studio_db < backup_20240115.sql
```

### Environment File Backup
```bash
cp .env.production .env.production.backup_$(date +%Y%m%d)
```

## 10. Troubleshooting

### Check container health
```bash
curl http://localhost:3000/api/health
```

### Reset everything
```bash
docker-compose down -v  # Remove containers and volumes
docker-compose up -d     # Start fresh
```

### Debug mode
```bash
docker run -it --rm \
  --env-file .env.production \
  ghcr.io/tesslateai/designer:latest \
  sh
```

## Important Security Notes

1. **Never commit `.env.production` to git**
2. **Use strong, unique passwords for all services**
3. **Restrict database access to only necessary hosts**
4. **Keep SSL certificates up to date**
5. **Regular security updates**: `sudo apt update && sudo apt upgrade`
6. **Use firewall rules to restrict access**:
   ```bash
   sudo ufw allow 22/tcp  # SSH
   sudo ufw allow 80/tcp  # HTTP
   sudo ufw allow 443/tcp # HTTPS
   sudo ufw enable
   ```

## Support

For issues or questions:
- Check container logs: `docker logs studio-lite`
- Verify environment variables are loaded correctly
- Ensure all external services (database, LiteLLM) are accessible
- Check network connectivity between containers

---

**Note**: Replace all placeholder values with your actual production credentials before deployment!