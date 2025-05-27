#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para imprimir mensagens
print_message() {
    echo -e "${GREEN}[*] $1${NC}"
}

print_error() {
    echo -e "${RED}[!] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    print_error "Por favor, execute este script como root (sudo ./install_server.sh)"
    exit 1
fi

# Solicitar credenciais do GitHub
print_message "Configurando acesso ao GitHub..."
read -p "Digite seu usuário do GitHub: " GITHUB_USER
read -sp "Digite seu token do GitHub (não será mostrado): " GITHUB_TOKEN
echo ""

if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_TOKEN" ]; then
    print_error "Usuário ou token não fornecidos!"
    exit 1
fi

# Diretório base
BASE_DIR="/opt/agenda"
mkdir -p $BASE_DIR
cd $BASE_DIR

# Verificar e instalar dependências
print_message "Instalando dependências do sistema..."
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    git \
    python3 \
    python3-pip \
    postgresql-client

# Instalar Docker
if ! command -v docker &> /dev/null; then
    print_message "Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $SUDO_USER
    systemctl enable docker
    systemctl start docker
else
    print_warning "Docker já está instalado"
fi

# Instalar Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_message "Instalando Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    print_warning "Docker Compose já está instalado"
fi

# Configurar Git com credenciais temporárias
git config --global credential.helper store
echo "https://$GITHUB_USER:$GITHUB_TOKEN@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials

# Verificar e preparar diretório
if [ -d "$BASE_DIR/.git" ]; then
    print_message "Repositório Git já existe, atualizando..."
    cd $BASE_DIR
    git pull
elif [ -d "$BASE_DIR" ] && [ "$(ls -A $BASE_DIR)" ]; then
    print_warning "Diretório $BASE_DIR não está vazio"
    read -p "Deseja limpar o diretório antes de continuar? (s/N) " clean_dir
    if [[ $clean_dir =~ ^[Ss]$ ]]; then
        print_message "Limpando diretório..."
        rm -rf $BASE_DIR/*
        rm -rf $BASE_DIR/.[!.]*
    else
        print_error "Por favor, escolha um diretório vazio para a instalação"
        exit 1
    fi
fi

# Clonar o repositório
print_message "Clonando repositório..."
git clone https://github.com/Easy-Newt/agenda-python /tmp/agenda-temp
if [ $? -ne 0 ]; then
    print_error "Falha ao clonar repositório. Verifique suas credenciais do GitHub."
    rm -f ~/.git-credentials
    exit 1
fi

# Mover arquivos do repositório
cp -r /tmp/agenda-temp/* $BASE_DIR/
cp -r /tmp/agenda-temp/.[!.]* $BASE_DIR/ 2>/dev/null || true
rm -rf /tmp/agenda-temp

# Remover credenciais do Git após o clone
rm -f ~/.git-credentials
git config --global --unset credential.helper

# Criar arquivo .env
print_message "Configurando variáveis de ambiente..."
cat > .env << EOL
# Banco de dados
POSTGRES_USER=agenda
POSTGRES_PASSWORD=$(openssl rand -base64 12)
POSTGRES_DB=agenda_db
DATABASE_URL=postgresql://agenda:${POSTGRES_PASSWORD}@db:5432/agenda_db

# Grafana
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=$(openssl rand -base64 12)
GF_USERS_ALLOW_SIGN_UP=false

# Backend
BACKEND_PORT=8000
CORS_ORIGINS=http://localhost:3000

# Frontend
FRONTEND_PORT=3000
REACT_APP_API_URL=http://localhost:8000/api
EOL

# Criar diretórios necessários
print_message "Criando diretórios..."
mkdir -p {backups,postgres_data,prometheus_data,grafana_data,grafana/provisioning/{datasources,dashboards},prometheus}
chmod -R 777 {postgres_data,prometheus_data,grafana_data}

# Configurar Prometheus
print_message "Configurando Prometheus..."
cat > prometheus/prometheus.yml << EOL
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'backend'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/metrics'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - 'rules/*.yml'
EOL

# Configurar Grafana
print_message "Configurando Grafana..."

# Configurar fonte de dados do Prometheus
cat > grafana/provisioning/datasources/prometheus.yml << EOL
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: 15s
      queryTimeout: 60s
      httpMethod: POST
EOL

# Configurar dashboard provider
cat > grafana/provisioning/dashboards/provider.yml << EOL
apiVersion: 1

providers:
  - name: 'Agenda Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOL

# Criar dashboard padrão
cat > grafana/provisioning/dashboards/agenda-overview.json << EOL
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 20,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineInterpolation": "smooth",
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": true,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "single",
          "sort": "none"
        }
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "expr": "rate(process_cpu_seconds_total[5m]) * 100",
          "refId": "A"
        }
      ],
      "title": "CPU Usage",
      "type": "timeseries"
    }
  ],
  "refresh": "5s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Agenda Overview",
  "uid": "agenda-overview",
  "version": 1,
  "weekStart": ""
}
EOL

# Configurar PostgreSQL
print_message "Configurando PostgreSQL..."

# Criar arquivo de configuração do PostgreSQL
cat > postgres/postgresql.conf << EOL
# Configurações de Memória
shared_buffers = 256MB
work_mem = 16MB
maintenance_work_mem = 64MB

# Configurações de Write-Ahead Log
wal_level = replica
max_wal_senders = 10
wal_keep_segments = 32

# Configurações de Conexão
max_connections = 100
superuser_reserved_connections = 3

# Configurações de Performance
effective_cache_size = 1GB
random_page_cost = 1.1
checkpoint_completion_target = 0.9
autovacuum = on
EOL

# Criar arquivo de configuração de acesso
cat > postgres/pg_hba.conf << EOL
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all            all                                     trust
host    all            all             127.0.0.1/32           md5
host    all            all             ::1/128                 md5
host    all            all             0.0.0.0/0              md5
EOL

# Criar ou atualizar docker-compose.yml
print_message "Configurando docker-compose.yml..."
cat > docker-compose.yml << EOL
version: '3.8'

services:
  db:
    image: postgres:14
    environment:
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_DB=\${POSTGRES_DB}
      - POSTGRES_MAX_CONNECTIONS=100
      - POSTGRES_SHARED_BUFFERS=256MB
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/postgresql.conf:/etc/postgresql/postgresql.conf
      - ./postgres/pg_hba.conf:/etc/postgresql/pg_hba.conf
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - agenda-network

  backend:
    build: ./backend
    environment:
      - DATABASE_URL=\${DATABASE_URL}
    ports:
      - "\${BACKEND_PORT}:8000"
    depends_on:
      - db
    networks:
      - agenda-network

  frontend:
    build: ./frontend
    environment:
      - REACT_APP_API_URL=\${REACT_APP_API_URL}
    ports:
      - "\${FRONTEND_PORT}:3000"
    depends_on:
      - backend
    networks:
      - agenda-network

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports:
      - "9090:9090"
    networks:
      - agenda-network

  grafana:
    image: grafana/grafana:latest
    environment:
      - GF_SECURITY_ADMIN_USER=\${GF_SECURITY_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=\${GF_SECURITY_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=\${GF_USERS_ALLOW_SIGN_UP}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    ports:
      - "3001:3000"
    depends_on:
      - prometheus
    networks:
      - agenda-network

  node-exporter:
    image: prom/node-exporter:latest
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - agenda-network

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    environment:
      - DATA_SOURCE_NAME=postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@db:5432/\${POSTGRES_DB}?sslmode=disable
    ports:
      - "9187:9187"
    depends_on:
      - db
    networks:
      - agenda-network

networks:
  agenda-network:
    driver: bridge

volumes:
  postgres_data:
  prometheus_data:
  grafana_data:
EOL

# Configurar firewall (ufw)
print_message "Configurando firewall..."
ufw allow 22/tcp
ufw allow 3000/tcp
ufw allow 8000/tcp
ufw allow 3001/tcp
ufw --force enable

# Iniciar serviços
print_message "Iniciando serviços..."
docker-compose down -v
docker-compose pull
docker-compose build
docker-compose up -d

# Aguardar serviços iniciarem
print_message "Aguardando serviços iniciarem..."
sleep 30

# Executar migrações
print_message "Executando migrações do banco de dados..."
docker-compose exec -T backend alembic upgrade head

# Configurar backup automático
print_message "Configurando backup automático..."
cat > /etc/cron.daily/agenda-backup << EOL
#!/bin/bash
cd $BASE_DIR
docker-compose exec -T db pg_dump -U agenda agenda_db > backups/backup-\$(date +%Y%m%d).sql
find backups/ -name "backup-*.sql" -mtime +7 -delete
EOL
chmod +x /etc/cron.daily/agenda-backup

# Configurar monitoramento de logs
print_message "Configurando monitoramento de logs..."
cat > /etc/logrotate.d/agenda << EOL
$BASE_DIR/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
EOL

# Imprimir informações importantes
print_message "\nInstalação concluída!\n"
echo -e "${GREEN}Acessos:${NC}"
echo -e "Frontend: http://localhost:3000"
echo -e "Backend: http://localhost:8000"
echo -e "Grafana: http://localhost:3001"
echo -e "\n${GREEN}Credenciais:${NC}"
echo -e "Grafana - usuário: admin"
echo -e "Grafana - senha: $(grep GF_SECURITY_ADMIN_PASSWORD .env | cut -d '=' -f2)"
echo -e "Banco de dados - senha: $(grep POSTGRES_PASSWORD .env | cut -d '=' -f2)"
echo -e "\n${GREEN}Diretórios importantes:${NC}"
echo -e "Backups: $BASE_DIR/backups"
echo -e "Logs: $BASE_DIR/logs"
echo -e "\n${YELLOW}Importante: Guarde as senhas geradas em um local seguro!${NC}\n"

# Verificar status dos serviços
print_message "Status dos serviços:"
docker-compose ps

# Instruções finais
echo -e "\n${GREEN}Para visualizar os logs:${NC}"
echo "docker-compose logs -f"
echo -e "\n${GREEN}Para reiniciar os serviços:${NC}"
echo "docker-compose restart"
echo -e "\n${GREEN}Para parar os serviços:${NC}"
echo "docker-compose down"

# Criar diretório para backups do PostgreSQL
mkdir -p postgres/backups
chmod 777 postgres/backups

# Criar script de backup do PostgreSQL
cat > postgres/backup.sh << EOL
#!/bin/bash
BACKUP_DIR="/var/lib/postgresql/backups"
BACKUP_NAME="backup-\$(date +%Y%m%d-%H%M%S).sql"
pg_dump -U \$POSTGRES_USER \$POSTGRES_DB > "\$BACKUP_DIR/\$BACKUP_NAME"
find "\$BACKUP_DIR" -name "backup-*.sql" -mtime +7 -delete
EOL
chmod +x postgres/backup.sh 