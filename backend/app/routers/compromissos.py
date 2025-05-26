from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timedelta
from ..database import get_db
from .. import models, schemas

router = APIRouter()

@router.post("/", response_model=schemas.Compromisso)
def criar_compromisso(compromisso: schemas.CompromissoCreate, db: Session = Depends(get_db)):
    # Validação de data e hora
    try:
        data_hora_inicio = datetime.strptime(f"{compromisso.data} {compromisso.hora_inicio}", "%d/%m/%Y %H:%M")
        if compromisso.hora_fim:
            data_hora_fim = datetime.strptime(f"{compromisso.data} {compromisso.hora_fim}", "%d/%m/%Y %H:%M")
            if data_hora_fim <= data_hora_inicio:
                raise HTTPException(status_code=400, detail="A hora de término deve ser posterior à hora de início")

        if data_hora_inicio < datetime.now():
            raise HTTPException(status_code=400, detail="Não é possível agendar compromissos no passado")

        # Criar compromisso base
        compromisso_dict = compromisso.dict()
        
        # Se for compromisso recorrente
        if compromisso.recorrencia:
            compromissos_criados = []
            tipo_recorrencia = compromisso.recorrencia.get('tipo')
            ate_data = datetime.strptime(compromisso.recorrencia.get('ate_data'), "%d/%m/%Y")
            data_atual = data_hora_inicio

            while data_atual.date() <= ate_data.date():
                novo_compromisso = models.Compromisso(
                    **{**compromisso_dict, 'data': data_atual.strftime("%d/%m/%Y")}
                )
                db.add(novo_compromisso)
                compromissos_criados.append(novo_compromisso)

                if tipo_recorrencia == 'diaria':
                    data_atual += timedelta(days=1)
                elif tipo_recorrencia == 'semanal':
                    data_atual += timedelta(days=7)
                elif tipo_recorrencia == 'dias_especificos':
                    data_atual += timedelta(days=1)
                    while data_atual.weekday() not in compromisso.recorrencia.get('dias_semana', []):
                        data_atual += timedelta(days=1)
                elif tipo_recorrencia == 'mensal':
                    proximo_mes = data_atual.month + 1
                    proximo_ano = data_atual.year
                    if proximo_mes > 12:
                        proximo_mes = 1
                        proximo_ano += 1
                    try:
                        data_atual = data_atual.replace(year=proximo_ano, month=proximo_mes)
                    except ValueError:
                        data_atual = (data_atual.replace(year=proximo_ano, month=proximo_mes + 1, day=1) 
                                    - timedelta(days=1))

            db.commit()
            for comp in compromissos_criados:
                db.refresh(comp)
            return compromissos_criados[0]
        else:
            # Compromisso único
            db_compromisso = models.Compromisso(**compromisso_dict)
            db.add(db_compromisso)
            db.commit()
            db.refresh(db_compromisso)
            return db_compromisso

    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Erro de formato: {str(e)}")

@router.get("/", response_model=List[schemas.Compromisso])
def listar_compromissos(periodo: str = None, db: Session = Depends(get_db)):
    query = db.query(models.Compromisso)
    
    if periodo:
        hoje = datetime.now()
        if periodo == "hoje":
            query = query.filter(models.Compromisso.data == hoje.strftime("%d/%m/%Y"))
        elif periodo == "semana":
            proxima_semana = hoje + timedelta(days=7)
            datas = [(hoje + timedelta(days=x)).strftime("%d/%m/%Y") for x in range(8)]
            query = query.filter(models.Compromisso.data.in_(datas))
        elif periodo == "mes":
            proximo_mes = hoje + timedelta(days=30)
            datas = [(hoje + timedelta(days=x)).strftime("%d/%m/%Y") for x in range(31)]
            query = query.filter(models.Compromisso.data.in_(datas))
    
    return query.all()

@router.get("/{compromisso_id}", response_model=schemas.Compromisso)
def obter_compromisso(compromisso_id: int, db: Session = Depends(get_db)):
    compromisso = db.query(models.Compromisso).filter(models.Compromisso.id == compromisso_id).first()
    if compromisso is None:
        raise HTTPException(status_code=404, detail="Compromisso não encontrado")
    return compromisso

@router.put("/{compromisso_id}", response_model=schemas.Compromisso)
def atualizar_compromisso(
    compromisso_id: int, 
    compromisso: schemas.CompromissoCreate, 
    atualizar_serie: bool = False,
    db: Session = Depends(get_db)
):
    db_compromisso = db.query(models.Compromisso).filter(models.Compromisso.id == compromisso_id).first()
    if db_compromisso is None:
        raise HTTPException(status_code=404, detail="Compromisso não encontrado")

    if atualizar_serie and db_compromisso.recorrencia:
        # Atualiza todos os compromissos da série
        grupo_id = db_compromisso.recorrencia.get('grupo_id')
        compromissos_serie = db.query(models.Compromisso).filter(
            models.Compromisso.recorrencia['grupo_id'].astext == grupo_id
        ).all()
        
        for comp in compromissos_serie:
            for key, value in compromisso.dict(exclude={'data'}).items():
                setattr(comp, key, value)
    else:
        # Atualiza apenas o compromisso específico
        for key, value in compromisso.dict().items():
            setattr(db_compromisso, key, value)
        if db_compromisso.recorrencia:
            db_compromisso.recorrencia = None

    db.commit()
    db.refresh(db_compromisso)
    return db_compromisso

@router.delete("/{compromisso_id}")
def excluir_compromisso(
    compromisso_id: int, 
    excluir_serie: bool = False,
    db: Session = Depends(get_db)
):
    compromisso = db.query(models.Compromisso).filter(models.Compromisso.id == compromisso_id).first()
    if compromisso is None:
        raise HTTPException(status_code=404, detail="Compromisso não encontrado")

    if excluir_serie and compromisso.recorrencia:
        # Exclui todos os compromissos da série
        grupo_id = compromisso.recorrencia.get('grupo_id')
        db.query(models.Compromisso).filter(
            models.Compromisso.recorrencia['grupo_id'].astext == grupo_id
        ).delete(synchronize_session=False)
    else:
        # Exclui apenas o compromisso específico
        db.delete(compromisso)

    db.commit()
    return {"message": "Compromisso(s) excluído(s) com sucesso"} 