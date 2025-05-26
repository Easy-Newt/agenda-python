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
    allow_origins=["http://localhost:3000"],
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