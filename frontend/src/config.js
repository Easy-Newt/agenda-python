// Obtém o hostname atual (IP ou domínio)
const currentHost = window.location.hostname;

// Configuração da API
export const API_CONFIG = {
    // Se estiver em desenvolvimento (localhost), usa localhost
    // Caso contrário, usa o IP/domínio atual
    baseURL: currentHost === 'localhost' 
        ? 'http://localhost:8000/api'
        : `http://${currentHost}:8000/api`
};

// Outras configurações
export const APP_CONFIG = {
    version: '1.0.0',
    name: 'Agenda'
}; 