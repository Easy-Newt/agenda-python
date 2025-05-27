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

# Clonar o repositório (se não existir)
if [ ! -d "$BASE_DIR/.git" ]; then
    print_message "Clonando repositório..."
    git clone https://github.com/Easy-Newt/agenda-python.git .
    if [ $? -ne 0 ]; then
        print_error "Falha ao clonar repositório. Verifique suas credenciais do GitHub."
        rm -f ~/.git-credentials
        exit 1
    fi
else
    print_message "Atualizando repositório..."
    git pull
fi

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
mkdir -p {backups,postgres_data,prometheus_data,grafana_data}
chmod -R 777 {postgres_data,prometheus_data,grafana_data}

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