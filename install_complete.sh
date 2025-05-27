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
    print_error "Por favor, execute este script como root (sudo ./install_complete.sh)"
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

# Configurar Git com credenciais temporárias
git config --global credential.helper store
echo "https://$GITHUB_USER:$GITHUB_TOKEN@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials

# Diretório base
BASE_DIR="/opt/agenda"
mkdir -p $BASE_DIR
cd $BASE_DIR

# Clonar o repositório
print_message "Clonando repositório..."
REPO_URL="https://github.com/$GITHUB_USER/agenda-python.git"  # Ajuste para seu repositório
git clone $REPO_URL .
if [ $? -ne 0 ]; then
    print_error "Falha ao clonar repositório. Verifique suas credenciais do GitHub."
    rm -f ~/.git-credentials
    exit 1
fi

# Remover credenciais do Git após o clone
rm -f ~/.git-credentials
git config --global --unset credential.helper

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

# Criar diretórios necessários
print_message "Criando diretórios..."
mkdir -p {backups,postgres_data,prometheus_data,grafana_data,grafana/provisioning/{datasources,dashboards},prometheus}
chmod -R 777 {postgres_data,prometheus_data,grafana_data}

# Configurar frontend com IP dinâmico
print_message "Configurando frontend..."
mkdir -p frontend/src
cat > frontend/src/config.js << EOL
// Obtém o hostname atual (IP ou domínio)
const currentHost = window.location.hostname;

// Configuração da API
export const API_CONFIG = {
    // Se estiver em desenvolvimento (localhost), usa localhost
    // Caso contrário, usa o IP/domínio atual
    baseURL: currentHost === 'localhost' 
        ? 'http://localhost:8000/api'
        : \`http://\${currentHost}:8000/api\`
};

// Outras configurações
export const APP_CONFIG = {
    version: '1.0.0',
    name: 'Agenda'
};
EOL

# Configurar backend com CORS flexível
print_message "Configurando backend..."
mkdir -p backend/app
cat > backend/app/main.py << EOL
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from .database import engine, Base
from .routers import contatos, compromissos

# Cria as tabelas no banco de dados
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Agenda API")

# Configuração do CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite todas as origens
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuração do Prometheus
Instrumentator().instrument(app).expose(app)

# Rotas
app.include_router(contatos.router, prefix="/api/contatos", tags=["contatos"])
app.include_router(compromissos.router, prefix="/api/compromissos", tags=["compromissos"])

@app.get("/")
async def root():
    return {"message": "Bem-vindo à API da Agenda"}
EOL

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

# Configurar regras do Prometheus
mkdir -p prometheus/rules
cat > prometheus/rules/alerts.yml << EOL
groups:
  - name: agenda_alerts
    rules:
      - alert: HighCPUUsage
        expr: rate(process_cpu_seconds_total[5m]) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de CPU"
          description: "O uso de CPU está acima de 80% por 5 minutos"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de memória"
          description: "O uso de memória está acima de 85% por 5 minutos"

      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100 > 5
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Alta taxa de erros HTTP"
          description: "A taxa de erros HTTP 5xx está acima de 5% por 5 minutos"
EOL

# Configurar Grafana
print_message "Configurando Grafana..."
cat > grafana/provisioning/datasources/prometheus.yml << EOL
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOL

# Criar docker-compose.yml
print_message "Configurando docker-compose.yml..."
cat > docker-compose.yml << EOL
version: '3.8'

services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://agenda:agenda123@db:5432/agenda_db
    depends_on:
      - db
    volumes:
      - ./backend:/app
    networks:
      - agenda-network
    extra_hosts:
      - "host.docker.internal:host-gateway"

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    volumes:
      - ./frontend:/app
      - /app/node_modules
    depends_on:
      - backend
    networks:
      - agenda-network
    extra_hosts:
      - "host.docker.internal:host-gateway"

  db:
    image: postgres:14
    environment:
      - POSTGRES_USER=agenda
      - POSTGRES_PASSWORD=agenda123
      - POSTGRES_DB=agenda_db
      - POSTGRES_MAX_CONNECTIONS=100
      - POSTGRES_SHARED_BUFFERS=256MB
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - agenda-network

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    networks:
      - agenda-network

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
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
      - DATA_SOURCE_NAME=postgresql://agenda:agenda123@db:5432/agenda_db?sslmode=disable
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

# Configurar firewall
print_message "Configurando firewall..."
ufw allow 22/tcp
ufw allow 3000/tcp
ufw allow 8000/tcp
ufw allow 3001/tcp
ufw allow 9090/tcp
ufw allow 9187/tcp
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

# Obter IP da máquina
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Imprimir informações importantes
print_message "\nInstalação concluída!\n"
echo -e "${GREEN}Acessos:${NC}"
echo -e "Frontend: http://$IP_ADDRESS:3000"
echo -e "Backend: http://$IP_ADDRESS:8000"
echo -e "Grafana: http://$IP_ADDRESS:3001"
echo -e "\n${GREEN}Credenciais:${NC}"
echo -e "Grafana - usuário: admin"
echo -e "Grafana - senha: admin123"
echo -e "Banco de dados - usuário: agenda"
echo -e "Banco de dados - senha: agenda123"

# Verificar status dos serviços
print_message "\nStatus dos serviços:"
docker-compose ps

print_message "\nInstalação concluída com sucesso!" 