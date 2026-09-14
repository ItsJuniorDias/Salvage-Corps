# Salvage Corps

Deckbuilder roguelike narrativo WWI + cosmic horror. iOS 17+.

## Status

MVP funcional em landscape com:
- Sistema de progressão linear de operações (persistência UserDefaults)
- Sistema de áudio (music + SFX) com placeholders sintéticos
- 28 artes AI-generated (Mignola × Darkest Dungeon style)
- Animações Pow em todos os momentos-chave
- Tipografia coesa (New York + American Typewriter)
- 15 testes unitários no SalvageCore

## Build

Requer Xcode 15.0+.

1. Abre `Salvage Corps.xcodeproj`
2. ⌘R

Dependencies já configuradas: SalvageCore (local) + Pow (remote).

## Áudio

Placeholders sintéticos incluídos em `Salvage Corps/Audio/`. Ver `AUDIO_REAL.md` pra guia de substituição por tracks reais do Pixabay.

⚠️ **Pow requer licença paga (~$40-70/ano) pra publicar na App Store.** Compra em https://movingparts.io/pow quando estiver pronto.

## Roadmap

- [x] Combate MVP jogável
- [x] 28 artes integradas
- [x] Animações Pow
- [x] Landscape optimization
- [x] Sistema de progressão
- [x] Sistema de áudio
- [ ] Áudio real (substituir placeholders)
- [ ] Sistema de cicatrizes (cartas evoluem com uso)
- [ ] Sistema de fases pro boss
- [ ] Mapa de nós (run completa)
- [ ] Escolhas terminais entre atos
- [ ] Tela de acampamento com NPCs
- [ ] Camada meta (Henry, save file weirdness)
- [ ] Ato 2 e 3
