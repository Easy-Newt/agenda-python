# Guia de Instalação e Configuração

Este guia fornece instruções detalhadas para configurar o ambiente de desenvolvimento e produção do sistema de agenda.

## Pré-requisitos

### Docker e Docker Compose
1. Instale o Docker:
   - Windows: [Docker Desktop para Windows](https://docs.docker.com/desktop/install/windows-install/)
   - Linux: 
     ```bash
     curl -fsSL https://get.docker.com | sh
     sudo usermod -aG docker $USER
     ```
   - macOS: [Docker Desktop para Mac](https://docs.docker.com/desktop/install/mac-install/)

2. Verifique a instalação:
   ```bash
   docker --version
   docker-compose --version
   ```

## Configuração do Ambiente

### 1. Variáveis de Ambiente
Crie um arquivo `.env` na raiz do projeto:

```env
# Banco de dados
POSTGRES_USER=agenda
POSTGRES_PASSWORD=agenda123
POSTGRES_DB=agenda_db
DATABASE_URL=postgresql://agenda:agenda123@db:5432/agenda_db

# Grafana
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin123
GF_USERS_ALLOW_SIGN_UP=false

# Backend
BACKEND_PORT=8000
CORS_ORIGINS=http://localhost:3000

# Frontend
FRONTEND_PORT=3000
REACT_APP_API_URL=http://localhost:8000/api
```

### 2. Configuração do PostgreSQL
O PostgreSQL será configurado automaticamente pelo Docker Compose, mas você pode personalizar:

1. Ajuste as configurações no `docker-compose.yml`:
   ```yaml
   db:
     environment:
       - POSTGRES_MAX_CONNECTIONS=100
       - POSTGRES_SHARED_BUFFERS=256MB
   ```

2. Para backup automático, adicione ao `docker-compose.yml`:
   ```yaml
   db-backup:
     image: postgres:14
     volumes:
       - ./backups:/backups
       - postgres_data:/var/lib/postgresql/data
     command: |
       bash -c 'while true; do
         pg_dump -h db -U agenda agenda_db > /backups/backup-$$(date +%Y%m%d-%H%M%S).sql
         sleep 86400
       done'
     environment:
       - POSTGRES_PASSWORD=agenda123
   ```

### 3. Configuração do Prometheus
1. O arquivo `prometheus.yml` já está configurado, mas você pode adicionar mais alvos:
   ```yaml
   scrape_configs:
     - job_name: 'node-exporter'
       static_configs:
         - targets: ['node-exporter:9100']
     
     - job_name: 'postgres-exporter'
       static_configs:
         - targets: ['postgres-exporter:9187']
   ```

2. Para adicionar exportadores, adicione ao `docker-compose.yml`:
   ```yaml
   node-exporter:
     image: prom/node-exporter
     ports:
       - "9100:9100"
     networks:
       - agenda-network

   postgres-exporter:
     image: prometheuscommunity/postgres-exporter
     environment:
       - DATA_SOURCE_NAME=postgresql://agenda:agenda123@db:5432/agenda_db?sslmode=disable
     ports:
       - "9187:9187"
     networks:
       - agenda-network
   ```

### 4. Configuração do Grafana
1. Dashboards padrão serão criados automaticamente
2. Para adicionar mais dashboards, crie arquivos JSON em `./grafana/dashboards/`
3. Para adicionar fontes de dados, adicione ao `docker-compose.yml`:
   ```yaml
   grafana:
     environment:
       - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
   ```

### 5. Configuração de Rede
1. O sistema usa uma rede Docker dedicada (`agenda-network`)
2. Portas expostas:
   - Frontend: 3000 (http://localhost:3000)
   - Backend: 8000 (http://localhost:8000)
   - PostgreSQL: 5432
   - Prometheus: 9090
   - Grafana: 3001 (http://localhost:3001)

### 6. Segurança
1. Firewall:
   ```bash
   # Windows (PowerShell como administrador)
   New-NetFirewallRule -DisplayName "Agenda Frontend" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
   New-NetFirewallRule -DisplayName "Agenda Backend" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
   
   # Linux
   sudo ufw allow 3000/tcp
   sudo ufw allow 8000/tcp
   ```

### 7. Monitoramento
1. Métricas coletadas:
   - Requisições HTTP (total, latência, erros)
   - Uso de CPU e memória
   - Conexões de banco de dados
   - Logs de aplicação

2. Alertas:
   - Configure no Grafana:
     - Alto uso de CPU/memória
     - Erros HTTP 5xx
     - Latência elevada
     - Falhas de banco de dados

### 8. Backup e Recuperação
1. Backup do banco de dados:
   ```bash
   docker-compose exec db pg_dump -U agenda agenda_db > backup.sql
   ```

2. Restauração:
   ```bash
   docker-compose exec -T db psql -U agenda agenda_db < backup.sql
   ```

3. Backup de volumes:
   ```bash
   docker run --rm -v agenda-automacao_postgres_data:/volume -v $(pwd):/backup alpine tar -czf /backup/postgres_data.tar.gz /volume
   ```

## Inicialização do Sistema

1. Construa as imagens:
   ```bash
   docker-compose build
   ```

2. Inicie os serviços:
   ```bash
   docker-compose up -d
   ```

3. Execute as migrações:
   ```bash
   docker-compose exec backend alembic upgrade head
   ```

4. Verifique os logs:
   ```bash
   docker-compose logs -f
   ```

## Resolução de Problemas

### Banco de Dados
1. Conexão recusada:
   ```bash
   docker-compose exec db pg_isready -U agenda
   ```

2. Limpar dados:
   ```bash
   docker-compose down -v
   docker-compose up -d
   ```

### Containers
1. Reiniciar serviço:
   ```bash
   docker-compose restart [serviço]
   ```

2. Verificar logs:
   ```bash
   docker-compose logs [serviço]
   ```

### Rede
1. Teste de conectividade:
   ```bash
   docker-compose exec backend ping db
   ```

2. Verificar portas:
   ```bash
   docker-compose ps
   ```

## Manutenção

### Atualizações
1. Atualizar imagens:
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

2. Limpar recursos não utilizados:
   ```bash
   docker system prune
   ```

### Monitoramento
1. Verificar uso de recursos:
   ```bash
   docker stats
   ```

2. Verificar logs:
   ```bash
   docker-compose logs --tail=100 -f
   ```

## Ambiente de Desenvolvimento

1. Configurar hot-reload:
   ```bash
   # Backend
   docker-compose exec backend pip install watchdog[watchmedo]
   
   # Frontend
   docker-compose exec frontend npm install -g nodemon
   ```

2. Acessar shell:
   ```bash
   docker-compose exec backend /bin/bash
   docker-compose exec frontend /bin/sh
   ```

3. Executar testes:
   ```bash
   docker-compose exec backend pytest
   docker-compose exec frontend npm test
   ``` 