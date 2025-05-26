from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from .. import models, schemas

router = APIRouter()

@router.post("/", response_model=schemas.Contato)
def criar_contato(contato: schemas.ContatoCreate, db: Session = Depends(get_db)):
    db_contato = models.Contato(**contato.dict())
    db.add(db_contato)
    db.commit()
    db.refresh(db_contato)
    return db_contato

@router.get("/", response_model=List[schemas.Contato])
def listar_contatos(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    contatos = db.query(models.Contato).offset(skip).limit(limit).all()
    return contatos

@router.get("/{contato_id}", response_model=schemas.Contato)
def obter_contato(contato_id: int, db: Session = Depends(get_db)):
    contato = db.query(models.Contato).filter(models.Contato.id == contato_id).first()
    if contato is None:
        raise HTTPException(status_code=404, detail="Contato não encontrado")
    return contato

@router.put("/{contato_id}", response_model=schemas.Contato)
def atualizar_contato(contato_id: int, contato: schemas.ContatoCreate, db: Session = Depends(get_db)):
    db_contato = db.query(models.Contato).filter(models.Contato.id == contato_id).first()
    if db_contato is None:
        raise HTTPException(status_code=404, detail="Contato não encontrado")
    
    for key, value in contato.dict().items():
        setattr(db_contato, key, value)
    
    db.commit()
    db.refresh(db_contato)
    return db_contato

@router.delete("/{contato_id}")
def excluir_contato(contato_id: int, db: Session = Depends(get_db)):
    contato = db.query(models.Contato).filter(models.Contato.id == contato_id).first()
    if contato is None:
        raise HTTPException(status_code=404, detail="Contato não encontrado")
    
    db.delete(contato)
    db.commit()
    return {"message": "Contato excluído com sucesso"} 