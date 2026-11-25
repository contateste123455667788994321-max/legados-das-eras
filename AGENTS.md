# Legado das Eras — instruções do proprietário para o Codex

Trabalhe em português. O proprietário joga no Android e quer um jogo 2D de simulação autônoma com pixel art original, inspirado na riqueza visual de The Bonfire 2 e na simulação de WorldBox. Não prometa conclusão antes de verificar a versão realmente publicada. Preserve mundos existentes e a atualização interna por PCK.

## Estado da entrega
- Main possui a versão publicada 0.5.18 (código 23) na última verificação. Não confundir commits com atualização instalada.
- PR #1, branch arte-e-progressao-v3, reúne as mecânicas recentes. O run 45666100130 importou Godot corretamente e falhou em um teste de contagem de sprites (8 antigos, 9 agora); correção f16b6ff enviada. Verificar novo run e logs. Não suprimir falhas nem publicar antes da validação.
- Branch menu-vale-dourado contém a preparação da tela inicial aprovada; falta integrar a imagem original no caminho assets/landscape/legado_das_eras_vale_dourado.png e conciliar com o código atual. Não substituir scripts inteiros por uma versão antiga.
- As três referências aprovadas devem ser fornecidas pelo usuário (PNG da tela dourada, prancha visual de minas/forja e fichas, prancha humana). Ainda não estão integralmente incorporadas ao jogo. Arte conceitual não equivale à arte instalada.

## Aparência e experiência
- Tela inicial exatamente como a referência dourada: castelo à esquerda, vale, rio, montanhas, vilas, título dourado, três botões Carregar mundo, Mundos salvos, Opções. Animações discretas da água, fumaça, bandeiras e tochas. Não simplificar a composição.
- Humanos pixel art originais com proporções e detalhes da prancha inspirada em The Bonfire 2. Menores no mapa; profissões, idades, sexo, roupas, armas, animações de caminhada, trabalho e combate. Preservar animais e terreno já aprovados; melhorar bruxa, aranhas menores com pernas bem definidas, magia do cajado com carga, orbe, rastro e impacto.
- Mina detalhada com entrada, suportes, lanterna, minério; forja com forno, bigorna, telhado e fumaça; fogueira animada. Cabana tribal simples nível 1, casa detalhada aprovada níveis 2 e 3. Castelo do governante e guarda real.
- Fichas ao tocar humanos e animais: idade, nível, vida, nome/espécie, profissão/equipamento quando cabível. Cada espécie disponível também para inserção manual. Mapa aleatório, reiniciar/apagar mundo com confirmação. Não iniciar tribos com edifícios prontos.
- Natação somente nos pixels reais de água; pontes permitem caminhada. Preservar a aparência da água.
## Simulação
- Construção gradual mediante entrega física de madeira/pedra, ícones pequenos com quantidades faltantes sobre a obra, trabalhador carrega, descarrega e constrói. Castelo custa inicialmente 300 pedras e 150 madeira. Progressão de lança, ferro e aço com diferenças de dano.
- Em guerra, trabalhadores constroem paliçadas de madeira pontiaguda apenas em terra, rios como barreiras naturais, portão para aliados. Desmontam após guerra e reaproveitam parte da madeira. Vida inicial por segmento 150, portão 100; dano de estacas 4/1,2 s mitigado por armadura. Invasores rompem portão ou muralha; arqueiros de dentro e fora; passagem e rotas precisam de testes reais.
- Guerra não termina por paz aleatória: rendição e anexação como província, ou derrota do exército e queda do governante que recusa rendição. Preservar civis em combate direto. Personalidade e moral influenciam rendição.
- Estratégias ataque direto e cerco prolongado. Alimentos existentes, produção interna e pesca acessível influenciam duração. Bloqueio depende de tropas posicionadas; defensores podem lutar para romper cerco. Fome prolongada afeta vida e moral; família real e soldados têm prioridade quando há escassez, demais recebem porções menores. Produção sazonal inicial primavera 125%, verão 100%, outono 85%, inverno 20%, ajustada ao bioma. Testar economia e balanceamento.
## Critérios de conclusão
1. Incorporar referências reais e inspecionar visualmente jogo em funcionamento, não apenas importação de SVG/PNG. 
2. Godot 4.4.1: importação headless sem erros, smoke_test.gd e perfis player_scenarios.gd. Corrigir falhas de verdade; adicionar regressões para cerco, colheita e salvamento. 
3. Exportar APK e PCK, testar atualização interna, preservar saves, validar hash e versão do manifesto. Publicação automática só após testes, na main. Confirmar manifest.json e pacote realmente publicados; não declarar pronto antes.
4. Reportar claramente limitações de validação visual/Android. Não modificar o canal de atualização ou credenciais sem necessidade.
