# Organiza Finanças

Aplicativo Flutter baseado no documento `Esboco_App_Financas_Agricultura_Familiar.pdf`, separando o dinheiro do negócio e da família.

## Executar

Requer Flutter 3.38+ e Dart 3.10+. Validado com Flutter 3.47.8. Android, iOS e web já foram gerados.

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=supabase.json
```

Sem o `supabase.json` o app abre uma tela avisando que o banco de dados não está configurado.

## Banco de dados (Supabase gratuito)

Os dados de cada pessoa ficam na conta dela no Supabase, com login por e-mail e senha. O app também guarda uma cópia no aparelho, então funciona sem internet e envia as alterações quando a conexão volta.

1. Crie uma conta em <https://supabase.com> e um projeto no plano **Free**. Anote a senha do banco.
2. No painel do projeto, abra **SQL Editor**, cole o conteúdo de `supabase/migrations/20261029000000_finance_data.sql` e clique em **Run**. Isso cria a tabela `finance_data` com RLS: cada usuário só lê e altera os próprios dados.
3. Em **Project Settings → API Keys**, copie a **Project URL** e a **Publishable key** (`sb_publishable_...`). Nunca use a `secret`/`service_role` no app.
4. Copie `supabase.example.json` para `supabase.json` (já ignorado pelo Git) e preencha os dois valores.
5. Em **Authentication → Sign In / Providers → Email**, deixe **Confirm email** ligado para exigir confirmação. O app confirma com um **código** digitado na tela, sem abrir link. Para o e-mail trazer o código, abra **Authentication → Emails → Confirm signup** e substitua o corpo pelo conteúdo de `supabase/templates/confirm_signup.html` (ele usa `{{ .Token }}`). O envio de e-mails do plano gratuito tem limite baixo por hora; para muitos usuários, configure um SMTP próprio em **Authentication → Emails**.
6. Rode ou compile sempre com `--dart-define-from-file=supabase.json`, por exemplo `flutter build apk --dart-define-from-file=supabase.json`.

Observação: projetos gratuitos são pausados após cerca de uma semana sem acesso; reative pelo painel.

Se o Flutter não estiver no PATH, nesta máquina:

```powershell
& 'C:\Flutter\flutter_windows_3.47.8-stable\flutter\bin\flutter.bat' run -d chrome
```

Para Android, configure o Android SDK e um emulador ou dispositivo, execute `flutter devices` e `flutter run -d <id>`. iOS exige macOS e Xcode. A compilação nativa e o microfone precisam ser testados nos dispositivos de destino.

## Funcionalidades

- Primeiros passos guiados (rendas, reserva e gastos) com progresso.
- Cadastro de rendas dos dois bolsos, retirada vinculada e reserva do negócio.
- Adicionar, editar e excluir (com desfazer) entradas e gastos fixos, parcelados, variáveis e eventuais.
- Botão **Registrar gasto** em todas as telas: escolha a categoria e lance o gasto em dois toques.
- Limites com destaque opcional, histórico editável, sugestões de descrição, saldo, aviso a partir de 80%, estimativa diária e exclusão com desfazer.
- Voz em português na categoria selecionada, com revisão e confirmação antes de salvar. Entende “1.250”, “R$ 35,90” e “50 reais”. Também funciona digitando.
- Agenda nos períodos 1–7, 8–14, 15–21 e 22–fim do mês: resumo do que falta pagar e receber, contas atrasadas em destaque, filtros por bolso e toque na linha para marcar pago/recebido.
- Resultado previsto ou pago/recebido, lucratividade, retirada, reserva, caixa e histórico dos meses.
- Reserva com botão **Já guardei**, que soma o valor do mês ao saldo guardado (com desfazer).
- Repetição do planejamento do mês anterior mais próximo, com avanço de parcelas. Navegar até um mês novo só mostra um rascunho; ele é gravado na primeira alteração. Não copia pagamentos, gastos variáveis nem eventuais; meses já gravados ficam independentes.
- Tema claro e escuro, seguindo o sistema. No celular, formulários em tela cheia; no computador, cartões lado a lado.
- Seletor de mês em grade (toque no nome do mês) e gráfico de colunas do resultado do negócio.
- Conta com e-mail e senha no Supabase. Os dados ficam na nuvem e também no aparelho; sem internet, um aviso mostra que há alterações a enviar, com o botão **Enviar agora**. **Sair da conta** fica no topo da tela.
- No primeiro acesso, dados que já estavam no aparelho (de antes do login) são levados para a conta.
- Se os dados salvos não abrirem, o app permite copiá-los ou começar do zero guardando uma cópia.

O app inicia vazio. Os dados de exemplo de outubro de 2026 ficam em `test/demo_data.dart` e são usados só nos testes.

## Regras de cálculo

Valores são centavos inteiros. O resultado do negócio é entradas menos custos operacionais. A retirada entra automaticamente na família; ela reduz o caixa do negócio sem virar custo de produção. Nos totais de “Tudo” na agenda, transferências internas são excluídas para não duplicar movimentações.

O planejamento usa valores previstos de rendas, fixos, parcelas e eventuais, mais gastos variáveis registrados. O limite variável não é contado como gasto. O resultado pago/recebido usa apenas itens confirmados na agenda e lançamentos variáveis. Pagamentos parciais não são suportados.

Rendas com vários dias dividem o valor mensal igualmente entre eles, preservando os centavos. Dias 29–31 são ajustados ao último dia dos meses menores. Feira e ovos da demonstração usam os sábados reais de outubro de 2026. A agenda ilustrativa do PDF não fecha com todos os itens do planejamento; a agenda do app sempre deriva dos registros.

A reserva tem saldo guardado e alocação planejada por mês. Depois de transferir o dinheiro, toque em **Já guardei** para somar a alocação ao saldo; mudar a alocação de um mês já depositado desfaz essa marcação. No resultado “Pago e recebido”, só a reserva marcada como guardada é descontada do caixa.

## Armazenamento e limitações

Os registros ficam no Supabase e numa cópia local via `SharedPreferencesAsync` (separada por usuário), em JSON versionado. O app nativo permite cadastrar e consultar sem internet. Na web, primeiro carregamento e reabertura offline dependem dos recursos do navegador; não há service worker offline configurado.

Com conta, cada alteração grava no aparelho e envia o documento inteiro para a tabela `finance_data` do Supabase. Ao abrir, o app baixa a versão da nuvem, a não ser que existam alterações locais ainda não enviadas; nesse caso a versão do aparelho é enviada. Não há mesclagem: se o mesmo usuário editar offline em dois aparelhos ao mesmo tempo, vale a última versão enviada. O plano gratuito do Supabase não inclui backups automáticos diários para download; para registros críticos, considere o plano pago ou exportações periódicas pelo painel.

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

Os testes visuais geram imagens em `tmp/screenshots/`. Os ícones de Android (incluindo o adaptativo), iOS e web são gerados por `flutter test tool/generate_icons_test.dart`; edite as cores e o desenho nesse arquivo e rode de novo. O site compilado fica em `build/web/` e deve ser servido por HTTP. Antes de publicar em lojas, configure identificadores próprios (hoje `com.example.organiza_financas`), ícones e assinatura.
