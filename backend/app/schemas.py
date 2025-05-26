from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime

class ContatoBase(BaseModel):
    nome: str
    telefone: str
    email: Optional[str] = None
    endereco: Optional[str] = None

class ContatoCreate(ContatoBase):
    pass

class Contato(ContatoBase):
    id: int
    data_criacao: datetime

    class Config:
        from_attributes = True

class CompromissoBase(BaseModel):
    titulo: str
    data: str
    hora_inicio: str
    hora_fim: Optional[str] = None
    descricao: Optional[str] = None
    participantes: Optional[List[str]] = []
    recorrencia: Optional[Dict] = None

class CompromissoCreate(CompromissoBase):
    pass

class Compromisso(CompromissoBase):
    id: int
    data_criacao: datetime

    class Config:
        from_attributes = True 