import os
import json
from datetime import datetime, timedelta

class Agenda:
    def __init__(self):
        self.contatos = []
        self.compromissos = []
        self.arquivo_contatos = 'contatos.json'
        self.arquivo_compromissos = 'compromissos.json'
        self.carregar_dados()

    def carregar_dados(self):
        if os.path.exists(self.arquivo_contatos):
            with open(self.arquivo_contatos, 'r') as arquivo:
                self.contatos = json.load(arquivo)
        if os.path.exists(self.arquivo_compromissos):
            with open(self.arquivo_compromissos, 'r') as arquivo:
                self.compromissos = json.load(arquivo)

    def salvar_contatos(self):
        with open(self.arquivo_contatos, 'w') as arquivo:
            json.dump(self.contatos, arquivo, indent=4)

    def salvar_compromissos(self):
        with open(self.arquivo_compromissos, 'w') as arquivo:
            json.dump(self.compromissos, arquivo, indent=4)

    def adicionar_contato(self, nome, telefone, email="", endereco=""):
        contato = {
            'id': len(self.contatos) + 1,
            'nome': nome,
            'telefone': telefone,
            'email': email,
            'endereco': endereco,
            'data_criacao': datetime.now().strftime("%d/%m/%Y %H:%M:%S")
        }
        self.contatos.append(contato)
        self.salvar_contatos()
        return "Contato adicionado com sucesso!"

    def listar_contatos(self):
        if not self.contatos:
            return "Nenhum contato encontrado."
        return self.contatos

    def buscar_contato(self, termo):
        resultados = []
        for contato in self.contatos:
            if (termo.lower() in contato['nome'].lower() or 
                termo in contato['telefone']):
                resultados.append(contato)
        return resultados if resultados else "Nenhum contato encontrado."

    def editar_contato(self, id, nome=None, telefone=None, email=None, endereco=None):
        for contato in self.contatos:
            if contato['id'] == id:
                if nome: contato['nome'] = nome
                if telefone: contato['telefone'] = telefone
                if email: contato['email'] = email
                if endereco: contato['endereco'] = endereco
                self.salvar_contatos()
                return "Contato atualizado com sucesso!"
        return "Contato não encontrado."

    def excluir_contato(self, id):
        for i, contato in enumerate(self.contatos):
            if contato['id'] == id:
                del self.contatos[i]
                self.salvar_contatos()
                return "Contato excluído com sucesso!"
        return "Contato não encontrado."

    def adicionar_compromisso(self, titulo, data, hora_inicio, hora_fim=None, descricao="", participantes=None, recorrencia=None):
        try:
            data_hora_inicio = datetime.strptime(f"{data} {hora_inicio}", "%d/%m/%Y %H:%M")
            data_hora_fim = None
            if hora_fim:
                data_hora_fim = datetime.strptime(f"{data} {hora_fim}", "%d/%m/%Y %H:%M")
                if data_hora_fim <= data_hora_inicio:
                    return "A hora de término deve ser posterior à hora de início."

            if data_hora_inicio < datetime.now():
                return "Não é possível agendar compromissos no passado."
            
            compromisso_base = {
                'titulo': titulo,
                'hora_inicio': hora_inicio,
                'hora_fim': hora_fim,
                'descricao': descricao,
                'participantes': participantes if participantes else [],
                'data_criacao': datetime.now().strftime("%d/%m/%Y %H:%M:%S")
            }

            if recorrencia:
                tipo_recorrencia = recorrencia['tipo']
                ate_data = datetime.strptime(recorrencia['ate_data'], "%d/%m/%Y")
                datas_compromisso = []
                data_atual = data_hora_inicio

                while data_atual.date() <= ate_data.date():
                    datas_compromisso.append(data_atual.strftime("%d/%m/%Y"))
                    
                    if tipo_recorrencia == 'diaria':
                        data_atual += timedelta(days=1)
                    elif tipo_recorrencia == 'semanal':
                        data_atual += timedelta(days=7)
                    elif tipo_recorrencia == 'dias_especificos':
                        # Avança para o próximo dia da semana especificado
                        data_atual += timedelta(days=1)
                        while data_atual.weekday() not in recorrencia['dias_semana']:
                            data_atual += timedelta(days=1)
                    elif tipo_recorrencia == 'mensal':
                        # Avança para o mesmo dia no próximo mês
                        proximo_mes = data_atual.month + 1
                        proximo_ano = data_atual.year
                        if proximo_mes > 12:
                            proximo_mes = 1
                            proximo_ano += 1
                        try:
                            data_atual = data_atual.replace(year=proximo_ano, month=proximo_mes)
                        except ValueError:
                            # Se o dia não existir no próximo mês, vai para o último dia
                            data_atual = (data_atual.replace(year=proximo_ano, month=proximo_mes + 1, day=1) - timedelta(days=1))

                # Cria um compromisso para cada data
                for data_comp in datas_compromisso:
                    novo_compromisso = compromisso_base.copy()
                    novo_compromisso['id'] = len(self.compromissos) + 1
                    novo_compromisso['data'] = data_comp
                    novo_compromisso['recorrencia'] = {
                        'tipo': tipo_recorrencia,
                        'grupo_id': data_hora_inicio.strftime("%Y%m%d%H%M%S")  # ID único para o grupo de recorrência
                    }
                    self.compromissos.append(novo_compromisso)

                self.compromissos.sort(key=lambda x: datetime.strptime(f"{x['data']} {x['hora_inicio']}", "%d/%m/%Y %H:%M"))
                self.salvar_compromissos()
                return f"Compromisso recorrente agendado com sucesso! Criados {len(datas_compromisso)} eventos."
            else:
                # Compromisso único
                compromisso_base['id'] = len(self.compromissos) + 1
                compromisso_base['data'] = data
                self.compromissos.append(compromisso_base)
                self.compromissos.sort(key=lambda x: datetime.strptime(f"{x['data']} {x['hora_inicio']}", "%d/%m/%Y %H:%M"))
                self.salvar_compromissos()
                return "Compromisso agendado com sucesso!"

        except ValueError as e:
            return f"Erro de formato: {str(e)}. Use DD/MM/AAAA para data e HH:MM para hora."

    def listar_compromissos(self, periodo=None):
        if not self.compromissos:
            return "Nenhum compromisso encontrado."
        
        hoje = datetime.now()
        compromissos_filtrados = []
        
        for compromisso in self.compromissos:
            data_comp = datetime.strptime(f"{compromisso['data']} {compromisso['hora_inicio']}", "%d/%m/%Y %H:%M")
            
            if periodo == "hoje" and data_comp.date() == hoje.date():
                compromissos_filtrados.append(compromisso)
            elif periodo == "semana" and data_comp.date() <= (hoje + timedelta(days=7)).date():
                compromissos_filtrados.append(compromisso)
            elif periodo == "mes" and data_comp.date() <= (hoje + timedelta(days=30)).date():
                compromissos_filtrados.append(compromisso)
            elif not periodo:
                compromissos_filtrados.append(compromisso)
        
        return compromissos_filtrados if compromissos_filtrados else "Nenhum compromisso encontrado para o período especificado."

    def buscar_compromisso(self, termo):
        resultados = []
        for compromisso in self.compromissos:
            if (termo.lower() in compromisso['titulo'].lower() or 
                termo.lower() in compromisso['descricao'].lower()):
                resultados.append(compromisso)
        return resultados if resultados else "Nenhum compromisso encontrado."

    def editar_compromisso(self, id, titulo=None, data=None, hora_inicio=None, hora_fim=None, descricao=None, participantes=None):
        compromisso = None
        for comp in self.compromissos:
            if comp['id'] == id:
                compromisso = comp
                break

        if not compromisso:
            return "Compromisso não encontrado."

        grupo_id = compromisso.get('recorrencia', {}).get('grupo_id')
        editar_serie = False

        if grupo_id:
            resposta = input("Este é um compromisso recorrente. Deseja editar toda a série? (s/n): ").lower()
            editar_serie = resposta == 's'

        if editar_serie:
            # Edita todos os compromissos do mesmo grupo
            for comp in self.compromissos:
                if comp.get('recorrencia', {}).get('grupo_id') == grupo_id:
                    if titulo: comp['titulo'] = titulo
                    if hora_inicio: comp['hora_inicio'] = hora_inicio
                    if hora_fim: comp['hora_fim'] = hora_fim
                    if descricao: comp['descricao'] = descricao
                    if participantes is not None: comp['participantes'] = participantes
            self.salvar_compromissos()
            return "Série de compromissos atualizada com sucesso!"
        else:
            # Edita apenas o compromisso específico
            if titulo: compromisso['titulo'] = titulo
            if data: compromisso['data'] = data
            if hora_inicio: compromisso['hora_inicio'] = hora_inicio
            if hora_fim: compromisso['hora_fim'] = hora_fim
            if descricao: compromisso['descricao'] = descricao
            if participantes is not None: compromisso['participantes'] = participantes
            
            # Remove a recorrência se for um evento de série
            if grupo_id:
                compromisso.pop('recorrencia', None)
            
            self.salvar_compromissos()
            return "Compromisso atualizado com sucesso!"

    def excluir_compromisso(self, id):
        compromisso = None
        for comp in self.compromissos:
            if comp['id'] == id:
                compromisso = comp
                break

        if not compromisso:
            return "Compromisso não encontrado."

        grupo_id = compromisso.get('recorrencia', {}).get('grupo_id')
        excluir_serie = False

        if grupo_id:
            resposta = input("Este é um compromisso recorrente. Deseja excluir toda a série? (s/n): ").lower()
            excluir_serie = resposta == 's'

        if excluir_serie:
            # Remove todos os compromissos do mesmo grupo
            self.compromissos = [comp for comp in self.compromissos 
                               if comp.get('recorrencia', {}).get('grupo_id') != grupo_id]
            self.salvar_compromissos()
            return "Série de compromissos excluída com sucesso!"
        else:
            # Remove apenas o compromisso específico
            self.compromissos.remove(compromisso)
            self.salvar_compromissos()
            return "Compromisso excluído com sucesso!"

def menu():
    print("\n=== AGENDA DE CONTATOS E COMPROMISSOS ===")
    print("=== CONTATOS ===")
    print("1. Adicionar Contato")
    print("2. Listar Contatos")
    print("3. Buscar Contato")
    print("4. Editar Contato")
    print("5. Excluir Contato")
    print("=== COMPROMISSOS ===")
    print("6. Adicionar Compromisso")
    print("7. Listar Compromissos")
    print("8. Buscar Compromisso")
    print("9. Editar Compromisso")
    print("10. Excluir Compromisso")
    print("11. Sair")
    return input("Escolha uma opção: ")

def main():
    agenda = Agenda()
    
    while True:
        opcao = menu()
        
        if opcao == "1":
            nome = input("Nome: ")
            telefone = input("Telefone: ")
            email = input("Email (opcional): ")
            endereco = input("Endereço (opcional): ")
            print(agenda.adicionar_contato(nome, telefone, email, endereco))

        elif opcao == "2":
            contatos = agenda.listar_contatos()
            if isinstance(contatos, list):
                for contato in contatos:
                    print(f"\nID: {contato['id']}")
                    print(f"Nome: {contato['nome']}")
                    print(f"Telefone: {contato['telefone']}")
                    print(f"Email: {contato['email']}")
                    print(f"Endereço: {contato['endereco']}")
                    print(f"Data de criação: {contato['data_criacao']}")
            else:
                print(contatos)

        elif opcao == "3":
            termo = input("Digite o nome ou telefone para buscar: ")
            resultados = agenda.buscar_contato(termo)
            if isinstance(resultados, list):
                for contato in resultados:
                    print(f"\nID: {contato['id']}")
                    print(f"Nome: {contato['nome']}")
                    print(f"Telefone: {contato['telefone']}")
                    print(f"Email: {contato['email']}")
                    print(f"Endereço: {contato['endereco']}")
            else:
                print(resultados)

        elif opcao == "4":
            id = int(input("ID do contato: "))
            nome = input("Novo nome (deixe em branco para manter): ")
            telefone = input("Novo telefone (deixe em branco para manter): ")
            email = input("Novo email (deixe em branco para manter): ")
            endereco = input("Novo endereço (deixe em branco para manter): ")
            print(agenda.editar_contato(id, nome or None, telefone or None, 
                                      email or None, endereco or None))

        elif opcao == "5":
            id = int(input("ID do contato a ser excluído: "))
            print(agenda.excluir_contato(id))

        elif opcao == "6":
            titulo = input("Título do compromisso: ")
            data = input("Data inicial (DD/MM/AAAA): ")
            hora_inicio = input("Hora de início (HH:MM): ")
            hora_fim = input("Hora de término (HH:MM): ")
            descricao = input("Descrição (opcional): ")
            
            participantes = []
            while True:
                participante = input("Adicionar participante? (Digite o nome ou deixe em branco para continuar): ")
                if not participante:
                    break
                participantes.append(participante)

            is_recorrente = input("Este é um compromisso recorrente? (s/n): ").lower() == 's'
            
            if is_recorrente:
                print("\nTipo de recorrência:")
                print("1. Diária")
                print("2. Semanal")
                print("3. Dias específicos da semana")
                print("4. Mensal")
                tipo_rec = input("Escolha o tipo de recorrência: ")
                
                ate_data = input("Data final da recorrência (DD/MM/AAAA): ")
                
                recorrencia = {
                    'ate_data': ate_data
                }
                
                if tipo_rec == "1":
                    recorrencia['tipo'] = 'diaria'
                elif tipo_rec == "2":
                    recorrencia['tipo'] = 'semanal'
                elif tipo_rec == "3":
                    recorrencia['tipo'] = 'dias_especificos'
                    print("\nSelecione os dias da semana (0-6, sendo 0=Segunda e 6=Domingo):")
                    dias = input("Digite os números separados por vírgula (ex: 1,3,5): ")
                    recorrencia['dias_semana'] = [int(d.strip()) for d in dias.split(',')]
                elif tipo_rec == "4":
                    recorrencia['tipo'] = 'mensal'
                
                print(agenda.adicionar_compromisso(titulo, data, hora_inicio, hora_fim, 
                                                 descricao, participantes, recorrencia))
            else:
                print(agenda.adicionar_compromisso(titulo, data, hora_inicio, hora_fim, 
                                                 descricao, participantes))

        elif opcao == "7":
            print("\nPeriodo de listagem:")
            print("1. Hoje")
            print("2. Próxima semana")
            print("3. Próximo mês")
            print("4. Todos")
            periodo_opcao = input("Escolha uma opção: ")
            periodo = {
                "1": "hoje",
                "2": "semana",
                "3": "mes",
                "4": None
            }.get(periodo_opcao)
            
            compromissos = agenda.listar_compromissos(periodo)
            if isinstance(compromissos, list):
                for comp in compromissos:
                    print(f"\nID: {comp['id']}")
                    print(f"Título: {comp['titulo']}")
                    print(f"Data: {comp['data']}")
                    print(f"Hora início: {comp['hora_inicio']}")
                    print(f"Hora término: {comp['hora_fim'] if comp.get('hora_fim') else 'Não definida'}")
                    print(f"Descrição: {comp['descricao']}")
                    print(f"Participantes: {', '.join(comp['participantes']) if comp['participantes'] else 'Nenhum'}")
                    if comp.get('recorrencia'):
                        print(f"Recorrência: {comp['recorrencia']['tipo']}")
            else:
                print(compromissos)

        elif opcao == "8":
            termo = input("Digite o título ou descrição para buscar: ")
            resultados = agenda.buscar_compromisso(termo)
            if isinstance(resultados, list):
                for comp in resultados:
                    print(f"\nID: {comp['id']}")
                    print(f"Título: {comp['titulo']}")
                    print(f"Data: {comp['data']}")
                    print(f"Hora início: {comp['hora_inicio']}")
                    print(f"Hora término: {comp['hora_fim'] if comp.get('hora_fim') else 'Não definida'}")
                    print(f"Descrição: {comp['descricao']}")
                    print(f"Participantes: {', '.join(comp['participantes']) if comp['participantes'] else 'Nenhum'}")
                    if comp.get('recorrencia'):
                        print(f"Recorrência: {comp['recorrencia']['tipo']}")
            else:
                print(resultados)

        elif opcao == "9":
            id = int(input("ID do compromisso: "))
            titulo = input("Novo título (deixe em branco para manter): ")
            data = input("Nova data (DD/MM/AAAA) (deixe em branco para manter): ")
            hora_inicio = input("Nova hora de início (HH:MM) (deixe em branco para manter): ")
            hora_fim = input("Nova hora de término (HH:MM) (deixe em branco para manter): ")
            descricao = input("Nova descrição (deixe em branco para manter): ")
            
            participantes = None
            if input("Deseja alterar participantes? (s/n): ").lower() == 's':
                participantes = []
                while True:
                    participante = input("Adicionar participante? (Digite o nome ou deixe em branco para continuar): ")
                    if not participante:
                        break
                    participantes.append(participante)
            
            print(agenda.editar_compromisso(id, titulo or None, data or None, 
                                          hora_inicio or None, hora_fim or None, 
                                          descricao or None, participantes))

        elif opcao == "10":
            id = int(input("ID do compromisso a ser excluído: "))
            print(agenda.excluir_compromisso(id))

        elif opcao == "11":
            print("Saindo da agenda...")
            break

        else:
            print("Opção inválida!")

if __name__ == "__main__":
    main() 