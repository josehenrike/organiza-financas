# Organiza Finanças

Aplicativo Flutter baseado no documento `Esboco_App_Financas_Agricultura_Familiar.pdf`, separando o dinheiro do negócio e da família.

## Executar

Requer Flutter 3.38+ e Dart 3.10+. Validado com Flutter 3.47.8. Android, iOS e web já foram gerados.

```powershell
flutter pub get
flutter run -d chrome
```

Se o Flutter não estiver no PATH, nesta máquina:

```powershell
& 'C:\Flutter\flutter_windows_3.47.8-stable\flutter\bin\flutter.bat' run -d chrome
```

Para Android, configure o Android SDK e um emulador ou dispositivo, execute `flutter devices` e `flutter run -d <id>`. iOS exige macOS e Xcode. A compilação nativa e o microfone precisam ser testados nos dispositivos de destino.

## Funcionalidades

- Cadastro de rendas dos dois bolsos, retirada vinculada e reserva do negócio.
- Adicionar, editar e excluir entradas e gastos fixos, parcelados, variáveis e eventuais.
- Limites com acompanhamento opcional, histórico, saldo, aviso a partir de 80%, estimativa diária e exclusão com confirmação.
- Voz em português na categoria selecionada, com revisão e confirmação antes de salvar. Também funciona digitando.
- Agenda nos períodos 1–7, 8–14, 15–21 e 22–fim do mês; filtros por bolso e marcação de pago/recebido.
- Resultado previsto ou pago/recebido, lucratividade, retirada, reserva planejada, caixa e histórico dos meses existentes.
- Repetição do planejamento do mês anterior mais próximo, com avanço de parcelas. Não copia pagamentos, gastos variáveis nem eventuais; meses já criados ficam independentes.
- Gravação local serializada, aviso de falha, backup JSON pela área de transferência e restauração validada com confirmação.

O app inicia vazio. Use **Conhecer o app com os exemplos do PDF** para explorar outubro de 2026. A demonstração fica identificada. **Sair da demonstração**, no menu, remove os exemplos e alterações feitas neles e permite começar seus registros.

## Regras de cálculo

Valores são centavos inteiros. O resultado do negócio é entradas menos custos operacionais. A retirada entra automaticamente na família; ela reduz o caixa do negócio sem virar custo de produção. Nos totais de “Tudo” na agenda, transferências internas são excluídas para não duplicar movimentações.

O planejamento usa valores previstos de rendas, fixos, parcelas e eventuais, mais gastos variáveis registrados. O limite variável não é contado como gasto. O resultado pago/recebido usa apenas itens confirmados na agenda e lançamentos variáveis. Pagamentos parciais não são suportados.

Rendas com vários dias dividem o valor mensal igualmente entre eles, preservando os centavos. Dias 29–31 são ajustados ao último dia dos meses menores. Feira e ovos da demonstração usam os sábados reais de outubro de 2026. A agenda ilustrativa do PDF não fecha com todos os itens do planejamento; a agenda do app sempre deriva dos registros.

A reserva tem saldo informado manualmente e alocação planejada por mês. Alterar a alocação não simula um depósito: atualize o saldo guardado depois de transferir o dinheiro. O resultado informa que a reserva descontada do caixa é planejada.

## Armazenamento e limitações

Os registros ficam neste dispositivo via `SharedPreferencesAsync`, em JSON versionado. O app nativo permite cadastrar e consultar sem internet. Na web, primeiro carregamento e reabertura offline dependem dos recursos do navegador; não há service worker offline configurado.

**Sincronização em nuvem ainda não implementada.** Ela precisa de backend, contas de usuário e estratégia de conflitos. Não há login, envio automático ou compartilhamento entre dispositivos. Exporte backups pelo menu: limpar os dados do navegador ou desinstalar o app pode remover os registros. Para produção com registros críticos, evoluir este armazenamento de MVP para banco transacional com migrações e backup automático.

O reconhecimento de voz depende das permissões e do serviço do sistema/navegador e pode exigir internet. O parser lê valores transcritos em algarismos; números por extenso devem ser corrigidos no formulário. Na web, microfone requer localhost ou HTTPS e navegador compatível. Android/iOS já incluem as declarações de permissão. Referência: https://pub.dev/packages/speech_to_text

## Estrutura

```text
lib/
  main.dart
  app/app.dart                         # Inicialização e localização
  core/theme/app_theme.dart            # Identidade visual
  features/finance/
    domain/finance.dart                # Modelos, cálculos, agenda e meses
    data/finance_store.dart            # Persistência local
    data/demo_data.dart                # Demonstração opcional
    presentation/finance_home.dart     # Cinco áreas principais
    presentation/item_form.dart        # Cadastro e edição
    presentation/limit_page.dart       # Gastos por categoria e voz
    presentation/finance_widgets.dart  # Componentes e formatação
test/                                  # Cálculos, persistência e interface
android/  ios/  web/                    # Plataformas
```

## Verificar e compilar

```powershell
dart format lib test
flutter analyze
flutter test
flutter build web --release
```

Os testes visuais geram imagens em `tmp/screenshots/`. O site compilado fica em `build/web/` e deve ser servido por HTTP. Antes de publicar em lojas, configure identificadores próprios (hoje `com.example.organiza_financas`), ícones e assinatura.
