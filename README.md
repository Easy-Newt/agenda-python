# Sistema de Agenda em Python

Um sistema simples de agenda desenvolvido em Python para gerenciar contatos.

## Funcionalidades

- Adicionar novos contatos
- Listar todos os contatos
- Buscar contatos por nome ou telefone
- Editar informações de contatos existentes
- Excluir contatos
- Armazenamento persistente em arquivo JSON

## Como usar

1. Certifique-se de ter Python 3.x instalado em seu sistema
2. Execute o arquivo `agenda.py`:
   ```
   python agenda.py
   ```
3. Use o menu interativo para navegar entre as opções:
   - 1: Adicionar novo contato
   - 2: Listar todos os contatos
   - 3: Buscar um contato
   - 4: Editar um contato existente
   - 5: Excluir um contato
   - 6: Sair do programa

## Armazenamento

Os contatos são armazenados no arquivo `contatos.json` no mesmo diretório do programa. Este arquivo é criado automaticamente na primeira vez que um contato for adicionado. 