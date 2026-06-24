Souza Transportes - Logística Inteligente

Este repositório contém a entrega da Parte 2 da disciplina de Desenvolvimento Móvel. O projeto evoluiu de um protótipo local (Parte 1) para um ecossistema completo com banco de dados na nuvem, rastreamento físico real por mapas, gestão de faturamento e governança de dados.

🎯 Objetivo do Projeto

O Souza Transportes é uma solução corporativa real desenvolvida para automatizar e auditar a cadeia logística de transporte de amostras biológicas e insumos médicos em Ponta Grossa - PR.

O aplicativo resolve gargalos operacionais críticos:

Fim do Registro Físico (Papel): Elimina erros de preenchimento manual e custos com redigitação de guias.

Auditoria de Deslocamento: Garante que o motoboy de fato realizou a rota através de monitoramento de GPS em tempo real e travas geográficas.

Mapeamento de Performance: Permite ao gestor diferenciar o tempo útil de trânsito do tempo ocioso do motorista aguardando liberação de insumos nas UPAs.

Transparência Financeira: Introduz um sistema dinâmico de tarifação de corridas, calculando com precisão o pagamento com base em dados auditados.

🚀 Requisitos Implementados (Parte 2)

O aplicativo foi melhorado com as seguintes implementações exigidas para a Parte 2:

1. Persistência em Banco de Dados Real (Supabase Cloud)

Integração completa com o Supabase para sincronização em tempo real de logs de corridas e dados cadastrais.

Sincronização Resiliente (Fila Offline): Se o motoboy estiver em trânsito sem conexão de internet (4G instável), as corridas são gravadas localmente via SharedPreferences. O gerenciador de estado (LogProvider) monitora a rede e realiza o upload da fila pendente automaticamente assim que o sinal for restabelecido.

Isolamento Estrito de Dados: Filtros de segurança aplicados no banco para garantir que cada motoboy visualize apenas o seu próprio histórico, mantendo as corridas de outros condutores sob sigilo absoluto.

2. Autenticação Real de Usuários

Tela de login integrada ao banco de dados para autenticação segura de Motoristas.

Rota de acesso alternativa para a plataforma administrativa (Admin) com controle de sessão ativa e desconexão assistida (AuthProvider).

3. Painel Administrativo ("Painel do Patrão")

Layout responsivo sem quebras de pixels ou estouro de tela (overflows).

Grid de KPIs Financeiros: Monitoramento de total de corridas, tempo de frota rodado e faturamento acumulado.

Gestão de Tarifas: Interface para o Admin reajustar livremente na nuvem os valores das entregas.

A Pagar por Condutor: Cartões informativos que exibem em tempo real quanto a empresa deve pagar para cada motoboy com base nas corridas executadas.

4. Regras Financeiras e Tarifação Dinâmica

Valor 1 (Trajeto Simples): Aplicado a rotas mistas (Upa ➔ Lab ou Lab ➔ Upa).

Valor 2 (Upa ➔ Upa): Tarifa diferenciada aplicada de forma inteligente quando o trajeto ocorre diretamente entre unidades de pronto atendimento.

Corrida Extra (Endereço Customizado): Botão interruptor de Rota Extra que permite ao motoboy digitar manualmente um endereço residencial (Rua, Número e Bairro) salvando os detalhes nas observações da entrega. O sistema trava automaticamente e de forma reativa a corrida na tarifa base (Valor 1).

5. Integração com Google Maps Real e Geofencing

Renderização física da rota no mapa usando o Google Map Controller com traçado de Polylines em tempo real a partir da API Google Directions.

Marcadores dinâmicos indicando a localização em tempo real do veículo (Ícone Ciano) e do destino cadastrado (Ícone Vermelho).

Trava Antifraude por GPS (Geofencing): O botão de finalizar corrida permanece bloqueado enquanto o dispositivo móvel estiver a mais de 50 metros do destino real. O chip de GPS físico monitora a distância via fórmula Haversine e só libera a conclusão ao aproximar-se da unidade.
(Para fins de demonstração acadêmica em sala de aula fechada, existe um botão discreto de "Forçar Chegada" para simular a aproximação e destravar o botão).

6. Relatórios e Compartilhamento Portátil (WhatsApp, etc.)

No Motorista: Opção de exportar o relatório financeiro de entregas filtrado exclusivamente por mês, gerando uma planilha formatada (.xlsx) com envio instantâneo e nativo para outros aplicativos do aparelho (WhatsApp do Financeiro, Telegram, E-mail, etc.).

No Admin: Exportação analítica gerada com base estritamente nos filtros de período e condutor ativos na tela do painel, gerando arquivos de auditoria com nomes autoexplicativos (ex: Relatorio_Admin_Souza_25_05_2026_Filtro_dia_Motorista_Renan.xlsx).

7. Segurança de Credenciais e Governança (.gitignore)

Nenhuma chave de API (Google Maps e chaves do Supabase) fica exposta no repositório público do GitHub.

Todas as chaves foram isoladas na pasta lib/config/env.dart, que foi adicionada permanentemente ao .gitignore.

O arquivo lib/config/env.example.dart foi adicionado ao Git sem as chaves reais para servir como template limpo para outros desenvolvedores.

🛠️ Arquitetura do Projeto (MVC)

O projeto segue um padrão arquitetural limpo e desacoplado:

Models (lib/models): TransporteLog atualizado para conter mapeamentos relacionais dinâmicos (toSupabaseMap()) e propriedades financeiras.

Views (lib/screens): Interfaces dinâmicas e reativas com o usuário (Login, Rota, Rastreamento, Admin e Relatórios).

Providers/Controllers (lib/providers): Gerenciadores reativos de estado local e global (LogProvider, AuthProvider e AdminProvider).

Services (lib/services): Lógica física e nativa de sensores, comunicação de rede e exportação de disco (GpsService, LogService e ScannerService).

📋 Guia de Telas e Fluxo de Uso

1. Tela de Login

Motorista: Insere suas credenciais. Se válidas no Supabase, o app injeta seu escopo operacional no gerenciador e o redireciona diretamente para a tela de trabalho (iniciar corrida), eliminando menus desnecessários.

Administrador: Acessa usando a credencial dedicada e entra no Dashboard de Gestão.

Diálogo de Saída Seguro: Se o usuário tentar voltar usando o botão físico do celular ou a seta superior nas telas principais do aplicativo, um diálogo é aberto para confirmar se ele deseja realmente deslogar do sistema, evitando perdas de sessão acidentais.

2. Tela de Nova Corrida (rota_screen.dart)

Exibe a identificação do condutor ativo e o local detectado pelo GPS.

Permite ler o código QR físico de uma caixa de amostras (processando o JSON real com câmera) ou preencher o formulário manualmente na mesma tela usando Dropdowns com as unidades cadastradas.

O painel exibe e recalcula o valor financeiro dinâmico a receber pela corrida em tempo real.

3. Tela de Rastreamento Ativo (rastreamento_screen.dart)

Renderiza o Google Maps em tempo real traçando a rota física de Ponta Grossa.

Exibe a telemetria do veículo (velocidade em km/h atualizada via sensores e distância restante até a unidade de destino).

Monitora o Geofencing bloqueando a conclusão até que o condutor se aproxime do destino.

4. Tela de Histórico do Motorista (relatorio_screen.dart)

Exibe a timeline de entregas do dia com indicador do status de sincronização (Nuvem ou Fila Local).

Exibe no cabeçalho o montante acumulado a receber pelas corridas do dia.

Botão para gerar e compartilhar a folha mensal via WhatsApp com a gerência.

5. Painel Administrativo (admin_dashboard_screen.dart)

Permite o cadastro de novos motoristas no banco centralizado.

Exibe faturamento global, tempo rodado e total de entregas baseado em filtros.

Permite alterar o valor base das tarifas que os motoristas recebem por corrida diretamente pelo celular.

🛠️ Como Executar o Projeto Localmente

Pré-requisitos

Flutter SDK instalado (versão estável).

Dispositivo físico ou emulador com os serviços de Google Play Services ativos (para o renderizador do Google Maps).

Configuração de Dependências

Certifique-se de ter os seguintes pacotes instalados no seu arquivo pubspec.yaml:

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  supabase_flutter: ^2.6.0
  geolocator: ^13.0.1
  google_maps_flutter: ^2.9.0
  http: ^1.2.2
  intl: ^0.19.0
  shared_preferences: ^2.2.3
  excel: ^4.0.8
  csv: ^6.0.0
  share_plus: ^10.1.0 # Necessário para o compartilhamento via WhatsApp
  uuid: ^4.4.0


Configuração de Credenciais

Navegue até a pasta lib/config/.

Duplique o arquivo env.example.dart e renomeie a cópia para env.dart.

Abra o arquivo env.dart e insira as suas chaves privadas do Supabase e do Google Maps:

class Env {
  static const String supabaseUrl = "SUA_URL_DO_SUPABASE";
  static const String supabaseAnonKey = "SUA_CHAVE_ANON_DO_SUPABASE";
  static const String googleMapsApiKey = "SUA_API_KEY_DO_GOOGLE_MAPS";
}


Executando o Aplicativo

Abra o terminal do projeto no VS Code e execute:

flutter pub get
flutter run

##  Como Executar no Android
Instalação Direta no Android (APK Pronto via GitHub Releases)

Passo a Passo para Instalação:

Acesse as Releases do Repositório:

No computador ou no navegador do celular, role a página deste repositório para cima.

No menu lateral direito (caso esteja no desktop) ou rolando a página inicial para baixo (no celular), localize e clique na seção "Releases".

Baixe o arquivo de Instalação:

Na release mais recente (ex: v2.0.0 ou v1.0.0), vá até o final da descrição e localize a aba Assets.

Clique no arquivo s_transporte.apk ou app-release.apk para realizar o download direto para o seu dispositivo móvel.

Habilite a instalação de fontes externas:

Abra o arquivo baixado no seu celular.

O sistema Android exibirá um aviso de segurança (padrão para aplicativos baixados fora da Google Play Store).

Toque em Configurações na caixa de diálogo e ative a permissão "Permitir desta fonte" (ou "Instalar aplicativos desconhecidos").

Instale e Execute:

Volte para a tela do instalador e clique em Instalar.

Quando o processo concluir, abra o aplicativo e faça o login usando as credenciais cadastradas no seu painel do Supabase!