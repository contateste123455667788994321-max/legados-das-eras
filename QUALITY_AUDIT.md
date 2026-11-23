# Legado das Eras — auditoria de 10 jogadores exigentes
Data: 2026-11-23. Comparação crítica com a experiência de simulação e profundidade de WorldBox (versão pública 0.51.x), não reprodução de artes, códigos ou identidade de WorldBox.
Referências visuais aprovadas: primeiro print de simulador tribal pixel art com mapa, aldeia, visor de personagem e HUD marrom-dourado; segundo print com biomas de deserto, floresta e neve de alta densidade.

## Régua de qualidade
Nota de 1 a 10: 1=quebrado, 5=protótipo funcional, 8=jogável com boa apresentação, 10=pronto para lançamento. Notas abaixo são *avaliação crítica do estado atual e dos prints*, não métricas de satisfação de pessoas reais, nem resultado de instalação física.

| # | Jogador simulado | Nota inicial | Critério de aprovação e defeito prioritário |
|---|------------------|--------------|----------------------------------------------|
| 1 | Observador | 4 | Calendário previsível, pausa sem progressão, evolução legível. Tempo acelerava demais; agora ano ~12 min em 1x. |
| 2 | Construtor | 3 | Produção, casas, recursos e progressão coerentes. Construções ainda não são uma ferramenta completa e intuitiva do jogador. |
| 3 | Explorador | 4 | Pinça com dois dedos, navegação sem cliques acidentais, câmera centrada. Implementado no código; precisa validar no touchscreen real. |
| 4 | Jogador do caos | 3 | 12 mundos estressados com guerras, animais, rivalidade, velocidades e inspeção de dados. Guerras ainda simplificadas. |
| 5 | Historiador de gerações | 4 | Pais identificados, crianças, herdeiros, sucessão consistente, acontecimentos persistentes. Relacionamentos precisam ser mais profundos. |
| 6 | Diplomata | 3 | Paz/aliança/guerra bilateral, registros e condições visíveis. Política ainda é simples frente a reinos, clãs e conspirações. |
| 7 | Ecologista | 3 | Regiões de biomas, rios, alimentos e materiais sem números negativos. Visual ainda não tem o nível das referências aprovadas. |
| 8 | Sobrevivente | 3 | Animais controláveis e ameaças coerentes. Ainda falta IA predatória, ciclo de fome e combate perceptível. |
| 9 | Crítico de arte e personagens | 2 | Sprites únicos de homens, mulheres e crianças; iluminação, materiais e silhuetas legíveis. Primeiros sprites eram minimalistas; redesenhados em camadas, mas o cenário ainda está distante da referência. |
| 10 | Jogador impaciente | 3 | Zoom extremo, múltiplos toques, velocidade e pausas repetidas, salvamento, estabilidade. Necessita testes no Poco e em aparelhos fracos. |

### Testes automatizados de verdade
Arquivo: `tests/player_scenarios.gd`. Cada perfil é executado em um job separado do GitHub Actions, com suas próprias instâncias de simulação. Dez jobs não equivalem a multiplayer real com dez celulares; testam código e invariantes. A compilação só pode acontecer após os dez passarem.

### Defeitos bloqueadores até ficar no nível solicitado
- Arte: criar/usar tiles de qualidade próxima às referências; arvores, sombras, cabanas, água, personagens animados, transições entre biomas. Não substituir com uma simples imagem de menu.
- Jogabilidade: visão do personagem é 2D ilustrada, **não é 3D jogável**; faltam câmera 3D, analógico, inventário, construções interativas e combate.
- UI: adaptação real para retrato e paisagem, controles menores em telas pequenas e dimensionamento de fonte.
- Mundo: IA social, aprendizagem cultural, comportamento de grupos, guerra territorial, religiões/linguagens e escolhas com consequências claras.
- Atualizações: URL pública confiável e assinatura permanente do APK; botão dentro do jogo ainda não tem canal de publicação funcional.
- Qualidade: validar desempenho real e instabilidade em aparelhos Android diferentes e jogos salvos antigos.

### Fontes oficiais de comparação
- https://www.superworldbox.com/changelog
- https://steamcommunity.com/app/1206560/allnews

Uso como inspiração de profundidade sistêmica, jamais copiar assets proprietários ou o nome do outro jogo.
