# Legado das Eras — Escopo combinado e critérios de entrega

Este projeto é independente de outros aplicativos. O objetivo é um **jogo completo para Android**, não apenas uma demonstração.
Não entregar APK ao usuário como versão final enquanto as funcionalidades e os testes abaixo não estiverem concluídos.

## Experiência de jogo
- [ ] Dois modos integrados: observar/controlar civilizações e assumir diretamente um personagem ou animal no mundo.
- [ ] Mundo vivo com biomas, aldeias, expansão territorial, culturas e eras distintas.
- [ ] Civilizações com reis/rainhas, linhagens, sucessão, famílias, nascimentos e mortes que alteram o mundo.
- [ ] Relações entre grupos, diplomacia, rivalidades e guerras com consequências permanentes.
- [ ] Fauna e perigos selvagens, com possibilidade de controlar animais.
- [ ] Visual Android completo, interface adequada para toque, controles móveis e identidade visual própria.

## Inteligência dos habitantes
- [x] Base offline de necessidades, profissões, personalidade e lembranças.
- [x] Integração da IA básica com o mundo e exibição de profissão/memória.
- [ ] Comportamentos coerentes ao longo de gerações, objetivos e decisões com consequências perceptíveis.
- [ ] Relações sociais mais profundas, lealdade, ambição, disputas políticas e eventos marcantes.
- [ ] Otimização de simulação: detalhes adaptativos conforme a capacidade do aparelho.

## Funcionamento para outras pessoas
- [x] Pausa lógica do tempo de simulação ao encerrar ou interromper o jogo.
- [x] Salvamento local básico e retomada da mesma história.
- [ ] Validar salvamento ao alternar apps, bloquear a tela e fechar em aparelhos reais.
- [ ] Funcionar offline no Android, sem custo obrigatório de servidores.
- [ ] Ajuste automático de desempenho e qualidade em celulares potentes e básicos.
- [ ] Testar estabilidade e desempenho em diferentes dispositivos Android.

## Distribuição e atualizações
- [x] Testes básicos Godot em GitHub Actions.
- [x] Construção de APK de depuração automatizada (somente teste).
- [x] Verificador de versões com URL HTTPS configurável; **desativado** até haver endereço público real.
- [ ] Criar canal público e seguro para distribuir manifest e APK aos jogadores.
- [ ] Configurar **assinatura permanente e protegida** do APK de produção. Builds debug não são substituto de uma chave de produção.
- [ ] Atualizar version_code e version_name a cada lançamento.
- [ ] Exibir aviso de versão nova e link para instalação; a instalação do APK depende de aprovação do Android/usuário.
- [ ] Confirmar atualização por cima da versão anterior sem perder o mundo salvo.
- [ ] Concluir todos os testes de funções e instalação real antes de publicar o APK completo.

## Contrato de atualização futura
Mudar código não significa disponibilizar automaticamente uma versão para os jogadores.
Cada versão destinada a jogadores será revisada, testada, assinada com a **mesma chave**,
com version_code incrementado, e publicada com manifesto de versão atualizado.
O jogo deve continuar jogável offline; uma política de atualização obrigatória
só poderá ser aplicada ao obter uma resposta válida do servidor público.

## Arquivo público de manifest (ainda não hospedado)
A futura URL configurada em res://config/version.json deve retornar um JSON assim:

{"version_code": 2, "version_name": "0.2.0", "apk_url": "https://ENDERECO_PUBLICO_VALIDO/Legado-das-Eras.apk", "required": false}

Nunca inserir tokens de acesso ao GitHub ou credenciais no APK.
