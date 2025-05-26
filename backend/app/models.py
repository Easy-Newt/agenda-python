from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from .database import Base
from datetime import datetime

class Contato(Base):
    __tablename__ = "contatos"

    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String, index=True)
    telefone = Column(String)
    email = Column(String)
    endereco = Column(String)
    data_criacao = Column(DateTime, default=datetime.now)

class Compromisso(Base):
    __tablename__ = "compromissos"

    id = Column(Integer, primary_key=True, index=True)
    titulo = Column(String, index=True)
    data = Column(String)
    hora_inicio = Column(String)
    hora_fim = Column(String)
    descricao = Column(String)
    participantes = Column(JSON)
    recorrencia = Column(JSON)
    data_criacao = Column(DateTime, default=datetime.now) 