# Direcao de arte obrigatoria — Legado das Eras

As duas imagens aprovadas pelo criador sao **referencias visuais do jogo funcional**, e nao telas para copiar como imagens estaticas.

## Primeira referencia: interface do simulador tribal

- Formato paisagem 16:9; pixel art detalhada e colorida.
- Mapa vivo ocupa a maior area da tela: rio sinuoso azul, margens, pontes, florestas densas com copas e sombras, cabanas de palha e madeira, fazendas cercadas com cultivos, fogueira, animais e aldeoes distintos.
- Borda e controles em tons de madeira escura, ouro envelhecido e pedra, sem aspecto de prototipo.
- Visao do personagem em miniatura **ao mesmo tempo** que o mapa geral, no canto direito superior. Personagem em primeira pessoa, ferramenta na mao, caminhos, aldeia e natureza.
- Painel do personagem logo abaixo: retrato, idade, tribo, funcao, caracteristicas e personalizacao.
- Faixa inferior com mini-paineis: biomas, as quatro estacoes, ciclo de vida (nascimento, infancia, adulto, velhice, morte) e evolucao da tribo.
- O mapa deve ser jogavel, com toque em habitantes, construcoes e regioes; mini-paineis e botoes operantes.

## Segunda referencia: biomas detalhados

- Deserto: cores de areia, relevo de terra, pedras, cactos, vegetacao seca, oases e construcoes que fazem sentido no ambiente.
- Floresta: copas altas sobrepostas, troncos, clareiras, sombras, recursos e fauna.
- Neve: pinheiros cobertos de neve, solo nevado com sombras azuladas e rochas.
- Planicie: verde natural, flores e agricultura.
- Montanhas: picos, rochas, minerais e caminhos.
- Biomas devem ser REGIOES CONTINUAS, nao ladrilhos aleatorios de cores desconexas.
- Climas influenciam fome, producao, recursos e adaptacao das aldeias ao longo das geracoes.

## Experiencia

- Humanos de diferentes idades, aparencias, sexos, personalidades e profissoes, com heranca, familia e descendencia.
- Personagens com escolhas e memoria e inteligencia local; criancas crescem, adultos envelhecem e morrem.
- Lobo e urso, construcoes, guerras, diplomacia e sucessao de lideres integrados ao mapa.
- Rodar offline, pausando e salvando quando o app sair, sem executar o mundo na nuvem enquanto fechado.
- Atualizacoes de conteudo devem ser baixaveis **dentro do jogo** via pacote Godot .pck verificado. O jogo so utiliza um manifesto publico HTTPS controlado pelo criador.
- Mudancas de Android nativo necessitam nova versao do APK, assinatura fixa e aceite do sistema.
- Nao chamar uma nova versao de igual as referencias antes de conferir visual e usabilidade em aparelho real.

## Estado de implementacao em 0.3.0

Parte dos paineis, rio e regioes de bioma, sprites e visao paralela esta implementada. Ainda faltam sprites profissionais de alta qualidade, animacoes, elementos visuais e mecanicas refinadas para atingir o detalhamento da arte original. O novo atualizador de pacotes depende de hospedagem oficial publica e de uma compilacao basica instalada uma vez; ainda nao e sistema de distribuicao em producao.
