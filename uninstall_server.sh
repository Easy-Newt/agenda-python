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
    print_error "Por favor, execute este script como root (sudo ./uninstall_server.sh)"
    exit 1
fi

# Diretório base
BASE_DIR="/opt/agenda"

# Confirmar desinstalação
echo -e "${RED}ATENÇÃO: Este script irá remover completamente a aplicação e todos os dados!${NC}"
echo -e "${RED}Isso inclui:${NC}"
echo "- Todos os containers Docker"
echo "- Banco de dados"
echo "- Arquivos de configuração"
echo "- Backups"
echo "- Logs"
read -p "Tem certeza que deseja continuar? (digite 'sim' para confirmar) " confirm
if [ "$confirm" != "sim" ]; then
    print_message "Operação cancelada."
    exit 0
fi

# Parar e remover containers
if [ -f "$BASE_DIR/docker-compose.yml" ]; then
    print_message "Parando e removendo containers..."
    cd $BASE_DIR
    docker-compose down -v
fi

# Remover imagens Docker
print_message "Removendo imagens Docker..."
docker rmi $(docker images -q 'agenda-*') 2>/dev/null || true

# Remover arquivos de backup do cron
print_message "Removendo tarefas de backup..."
rm -f /etc/cron.daily/agenda-backup

# Remover configuração do logrotate
print_message "Removendo configuração de logs..."
rm -f /etc/logrotate.d/agenda

# Remover regras do firewall
print_message "Removendo regras do firewall..."
ufw delete allow 3000/tcp
ufw delete allow 8000/tcp
ufw delete allow 3001/tcp

# Fazer backup final (opcional)
read -p "Deseja fazer um backup final antes de remover? (s/N) " backup
if [[ $backup =~ ^[Ss]$ ]]; then
    print_message "Realizando backup final..."
    BACKUP_DIR="/root/agenda-backup-final-$(date +%Y%m%d)"
    mkdir -p $BACKUP_DIR
    
    if [ -f "$BASE_DIR/docker-compose.yml" ]; then
        cd $BASE_DIR
        docker-compose exec -T db pg_dump -U agenda agenda_db > "$BACKUP_DIR/database.sql"
    fi
    
    # Copiar arquivos importantes
    cp -r $BASE_DIR/backups $BACKUP_DIR/ 2>/dev/null || true
    cp -r $BASE_DIR/logs $BACKUP_DIR/ 2>/dev/null || true
    cp $BASE_DIR/.env $BACKUP_DIR/ 2>/dev/null || true
    
    print_message "Backup final salvo em: $BACKUP_DIR"
fi

# Remover diretório da aplicação
print_message "Removendo arquivos da aplicação..."
rm -rf $BASE_DIR

print_message "\nDesinstalação concluída!"
echo -e "\n${YELLOW}Nota: O Docker e o Docker Compose não foram removidos.${NC}"
echo -e "Para removê-los, execute:"
echo "apt-get remove docker docker-ce docker-ce-cli containerd.io docker-compose"
echo -e "\n${GREEN}Todos os dados da aplicação foram removidos.${NC}"

if [[ $backup =~ ^[Ss]$ ]]; then
    echo -e "\n${YELLOW}Não esqueça de guardar o backup final em:${NC}"
    echo "$BACKUP_DIR"
fi 