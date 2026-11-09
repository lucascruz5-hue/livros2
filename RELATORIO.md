# RELATORIO – App "Meus Livros" (Flutter)

**Ideia escolhida:** D) Gerenciar livros lidos / desejados / Top 5 e compartilhar imagem do ranking.

## Funcionalidades
- CRUD de livros (adicionar, editar ao tocar, excluir deslizando para a esquerda)
- Duas listas: **Lidos** (com nota de 1 a 5 estrelas) e **Desejados**
- Aba **Top 5**: ranking dos livros lidos com maior nota
- Botão **Compartilhar imagem**: gera PNG do ranking e abre o menu de compartilhamento (WhatsApp, etc.)
- Persistência local com `shared_preferences` (JSON)

## Configuração
```bash
flutter create meus_livros
cd meus_livros
git init
# substituir pubspec.yaml e lib/main.dart pelos deste repositório
flutter pub get
flutter run
```

### Dependências (pubspec.yaml)
| Pacote | Uso |
|---|---|
| shared_preferences | salvar a lista de livros localmente |
| share_plus | compartilhar a imagem gerada |
| path_provider | pasta temporária para salvar o PNG |

## Programação (resumo)
- `Livro`: modelo com `toJson`/`fromJson`.
- `HomePage`: estado, carga/salvamento, formulário (`AlertDialog`), listas e ranking.
- Imagem: `RepaintBoundary` + `GlobalKey` → `toImage(pixelRatio: 3)` → PNG → `Share.shareXFiles`.
- Top 5: filtra lidos com nota > 0, ordena por nota decrescente, `take(5)`.

## Prompts utilizados
1. "Escolha uma das ideias abaixo para fazer um aplicativo FLUTTER... (opção D)" – enviado ao Claude com o print do enunciado.
2. "faça para mim" – pedido do código completo (main.dart, pubspec.yaml, relatório).

## Log de commits (atualizar a cada aula)
| Data | Commit | Descrição |
|---|---|---|
| 09/11/2026 | feat: projeto inicial | Estrutura, CRUD, Top 5 e compartilhamento |
