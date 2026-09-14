# Salvage Corps — Setup Xcode Manual

Guia passo a passo pra criar o projeto Xcode do jogo. Método clássico, funciona em qualquer Xcode 15+.

## Estrutura do zip

```
salvage_classic/
├── SalvageCorps/          ← Swift Package (library) das regras do jogo
│   ├── Package.swift
│   ├── Sources/SalvageCore/
│   └── Tests/SalvageCoreTests/
└── iOSAppFiles/           ← Arquivos pra colar no app iOS Xcode
    ├── SalvageApp.swift
    ├── CombatView.swift
    ├── GameStore.swift
    └── Resources/
        └── Assets.xcassets/  ← 28 imagesets
```

## Setup completo (10 minutos)

### Passo 1 — Criar projeto Xcode iOS (2 min)

1. Abre Xcode
2. **File → New → Project...** (⇧⌘N)
3. Escolhe **iOS** no topo → **App** → **Next**
4. Configura:
   - Product Name: **`SalvageApp`**
   - Team: **None** por enquanto (ou seu Personal Team)
   - Organization Identifier: **`com.salvagecorps`**
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None**
   - Include Tests: **desmarca** (não precisa)
5. **Next**
6. Escolhe onde salvar. **IMPORTANTE**: salva DENTRO da pasta `salvage_classic/` (a mesma pasta que tem `SalvageCorps/`). Estrutura vai ficar:
   ```
   salvage_classic/
   ├── SalvageCorps/      (já existe)
   ├── iOSAppFiles/       (já existe)
   └── SalvageApp/        ← novo, criado pelo Xcode
       ├── SalvageApp.xcodeproj
       └── SalvageApp/
   ```
7. **Desmarca** "Create Git repository" (opcional)
8. **Create**

Xcode abre com um projeto iOS vazio e um `ContentView.swift` template.

### Passo 2 — Adicionar SalvageCore como dependência local (2 min)

1. No Xcode, com o projeto SalvageApp aberto:
2. Menu **File → Add Package Dependencies...** (ou clique no ícone `+` embaixo do Package Dependencies no navigator, se aparecer)
3. Na janela que abre, clica no botão **"Add Local..."** no canto inferior esquerdo
4. Navega até a pasta **`salvage_classic/SalvageCorps`** (a pasta que TEM o Package.swift, não o Package.swift em si)
5. Clica **Add Package**
6. Na próxima tela, marca **SalvageCore** como library pra adicionar ao target **SalvageApp** → **Add Package**

Deve aparecer "SalvageCore" na seção "Package Dependencies" do navigator.

### Passo 3 — Adicionar Pow (a lib de animações) (2 min)

1. Menu **File → Add Package Dependencies...** de novo
2. Na barra de busca no canto superior direito, cola: `https://github.com/movingparts-io/Pow`
3. Enter. Aguarda Xcode resolver (~10-30s)
4. Quando aparecer "Pow" com opções, clica **Add Package**
5. Marca **Pow** para adicionar ao target **SalvageApp** → **Add Package**

Agora você tem 2 packages: SalvageCore (local) + Pow (remoto).

### Passo 4 — Deletar arquivos gerados pelo template (30s)

No project navigator (esquerda), dentro da pasta **SalvageApp/SalvageApp/**:
- **Deleta** `ContentView.swift` (Move to Trash quando perguntar)
- **NÃO** delete `SalvageApp.swift` — vai ser substituído

### Passo 5 — Colar os arquivos SwiftUI (2 min)

Do zip que você extraiu, pasta **`iOSAppFiles/`**:

1. **`SalvageApp.swift`** (o novo, com menu): abre no Finder, copia o conteúdo INTEIRO. No Xcode, abre o `SalvageApp.swift` existente (aquele criado pelo template), seleciona tudo (⌘A), cola por cima (⌘V), salva (⌘S).

2. **`GameStore.swift`**: no Finder, arrasta o arquivo pra dentro da pasta `SalvageApp` (embaixo do `SalvageApp.swift`) no project navigator do Xcode.
   - Na janela que abre: marca **"Copy items if needed"**
   - Added folders: **"Create groups"**
   - Add to targets: **SalvageApp** ✓
   - **Finish**

3. **`CombatView.swift`**: mesmo processo. Arrasta pra dentro da pasta SalvageApp, mesmas opções.

### Passo 6 — Adicionar as imagens (Asset Catalog) (2 min)

1. No Finder, entra em **`iOSAppFiles/Resources/`**
2. Você vai ver `Assets.xcassets` (é uma "pasta especial")
3. **Arrasta `Assets.xcassets` inteiro** pra dentro da pasta `SalvageApp` no Xcode navigator
   - Copy items if needed ✓
   - Add to targets: **SalvageApp** ✓
4. **IMPORTANTE**: pode aparecer conflito com o `Assets.xcassets` que o Xcode já criou por default. Se aparecer, **substitui**.

Alternativa mais segura: **primeiro deleta** o `Assets.xcassets` que o Xcode criou (o template cria um vazio), **depois** arrasta o do zip.

### Passo 7 — Build e run (30s)

1. Confirma que o destination (top-bar) é **iPhone 15 Pro** (ou qualquer simulador iOS 17+)
2. **⌘R** (ou botão ▶)

Xcode compila (~10-30s primeira vez) e abre o simulador com o menu do jogo.

## Se der erro

### "No such module 'SalvageCore'"
Package não foi adicionado ao target. Selecione o projeto `SalvageApp` no navigator → target `SalvageApp` → aba **General** → seção **Frameworks, Libraries, and Embedded Content** → clique `+` → escolhe SalvageCore.

### "No such module 'Pow'"
Mesma coisa que o SalvageCore, mas com Pow.

### "Image 'edmund' not found" ou similar em runtime
Asset Catalog não foi adicionado ao target. Clique no `Assets.xcassets` → File Inspector direito → **Target Membership** → marca `SalvageApp`.

### "Cannot find 'iOSApplication' in scope"
Não devia acontecer com esse setup, mas se acontecer: você ainda tá com o Package.swift antigo aberto por engano. Fecha ele, abre o SalvageApp.xcodeproj.

### Erros de compilação em CombatView.swift referenciando APIs do Pow
Pow não foi adicionado ao target ou versão errada. No navigator, expanda "Package Dependencies", verifica se Pow está lá. Se não, refaz o Passo 3.

## Testar as regras (opcional mas recomendado)

Antes de testar o app, valida que o core funciona:

```bash
cd salvage_classic/SalvageCorps
swift test
```

Deve rodar 15 testes em ~200ms, todos passando.

## Notas finais

- Pow requer licença paga pra publicar na App Store (~$40-70/ano em movingparts.io/pow). Grátis pra dev/TestFlight.
- O projeto Xcode você criou fica em `salvage_classic/SalvageApp/` — abre o `.xcodeproj` de dentro dela quando quiser trabalhar. NÃO abre o Package.swift do SalvageCorps sozinho — abre sempre o `.xcodeproj`.

Manda screenshot quando conseguir buildar. Se travar em algum passo específico, screenshot do que aparece na tela + qual passo travou.
