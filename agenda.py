import os
import json
from datetime import datetime

class Agenda:
    def __init__(self):
        self.contatos = []
        self.arquivo_dados = 'contatos.json'
        self.carregar_contatos()

    def carregar_contatos(self):
        if os.path.exists(self.arquivo_dados):
            with open(self.arquivo_dados, 'r') as arquivo:
                self.contatos = json.load(arquivo)

    def salvar_contatos(self):
        with open(self.arquivo_dados, 'w') as arquivo:
            json.dump(self.contatos, arquivo, indent=4)

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

def menu():
    print("\n=== AGENDA DE CONTATOS ===")
    print("1. Adicionar Contato")
    print("2. Listar Contatos")
    print("3. Buscar Contato")
    print("4. Editar Contato")
    print("5. Excluir Contato")
    print("6. Sair")
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
            print("Saindo da agenda...")
            break

        else:
            print("Opção inválida!")

if __name__ == "__main__":
    main() 