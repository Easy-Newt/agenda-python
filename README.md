# Sistema de Agenda

Sistema completo de agenda com gerenciamento de contatos e compromissos, incluindo suporte a compromissos recorrentes.

## Funcionalidades

### Contatos
- Adicionar, editar e excluir contatos
- Visualizar lista de contatos
- Campos: nome, telefone, email e endereço

### Compromissos
- Adicionar, editar e excluir compromissos
- Visualizar lista de compromissos
- Filtrar por período (hoje, próxima semana, próximo mês)
- Suporte a compromissos recorrentes:
  - Diários
  - Semanais
  - Dias específicos
  - Mensais
- Campos: título, data, horário de início e fim, descrição, participantes

## Tecnologias Utilizadas

### Backend
- Python 3.11
- FastAPI
- SQLAlchemy
- PostgreSQL
- Alembic (migrações)
- Prometheus (monitoramento)

### Frontend
- React
- Material-UI
- Axios
- Date-fns

### Infraestrutura
- Docker
- Docker Compose
- Grafana (monitoramento)

## Requisitos

- Docker
- Docker Compose

## Instalação e Execução

1. Clone o repositório:
```bash
git clone <url-do-repositorio>
cd agenda
```

2. Inicie os containers:
```bash
docker-compose up -d
```

3. Execute as migrações do banco de dados:
```bash
docker-compose exec backend alembic upgrade head
```

4. Acesse a aplicação:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- Documentação da API: http://localhost:8000/docs
- Grafana: http://localhost:3001 (usuário: admin, senha: admin123)
- Prometheus: http://localhost:9090

## Estrutura do Projeto

```
.
├── backend/
│   ├── app/
│   │   ├── models.py
│   │   ├── schemas.py
│   │   ├── database.py
│   │   └── routers/
│   ├── alembic/
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   └── App.js
│   ├── package.json
│   └── Dockerfile
├── prometheus/
│   └── prometheus.yml
└── docker-compose.yml
```

## Monitoramento

O sistema inclui monitoramento completo usando Prometheus e Grafana:

- Métricas da API (requisições, latência, erros)
- Métricas do banco de dados
- Dashboard personalizado no Grafana

## Desenvolvimento

Para desenvolvimento local:

1. Instale as dependências do backend:
```bash
cd backend
pip install -r requirements.txt
```

2. Instale as dependências do frontend:
```bash
cd frontend
npm install
```

3. Execute o backend em modo de desenvolvimento:
```bash
cd backend
uvicorn app.main:app --reload
```

4. Execute o frontend em modo de desenvolvimento:
```bash
cd frontend
npm start
```

## Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Crie um Pull Request

## Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo LICENSE para detalhes. 