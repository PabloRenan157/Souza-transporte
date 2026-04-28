##  Avaliação - Parte 1

Este repositório contém a entrega da **Parte 1** da disciplina, focada em UI, Navegação, Validação e Padrões de Projeto.

Objetivo do Projeto
O "Souza Transporte" surge da necessidade de modernizar e auditar o fluxo logístico no transporte de amostras biológicas. Atualmente baseado em registros manuais (papel), o processo enfrenta desafios críticos como a falta de integridade nos horários informados, morosidade na consolidação de dados para planilhas e a dificuldade em identificar gargalos operacionais.

*O app está sendo desenvolvido para uma aplicação real*

O sistema visa:

*   Digitalização e Automação: Eliminar o uso de formulários físicos, automatizando a coleta de dados de saída, destino e chegada, reduzindo custos operacionais com redigitação de dados.
*   Auditoria e Precisão: Garantir a veracidade dos tempos de trânsito através de geolocalização em tempo real, evitando distorções nos registros de horários.
*   Gestão de Performance: Distinguir com precisão o tempo de deslocamento do motoboy do tempo de espera nas unidades de saúde (tempo ocioso), permitindo ao gestor identificar se a demora ocorre no transporte ou no atendimento laboratorial.
*   Otimização Financeira: Proporcionar uma base de dados confiável para o pagamento de prêmios por agilidade, garantindo que a bonificação seja aplicada de forma justa e baseada em dados reais de produtividade.

###  Requisitos Implementados
*   **Objetivo do Aplicativo (0,5):** Sistema focado em logística de saúde pública e Otimização Financeira e de performance.
*   **Uso de Formulários (1,5):** Implementação de `TextFormField` com validadores para entrada manual de dados.
*   **Validações e Feedback (1,0):** Tratamento de erros de GPS, leitura de QR Code inválido e validação de campos vazios.
*   **Estrutura e Padronização (2,0):** Arquitetura **MVC** (Models, Views, Controllers/Services).
*   **Navegação entre Páginas (1,5):** Fluxo completo entre escolha de usuário, Seleção de Rota, Mapa em Tempo Real e Relatórios.
*   **Interface Adequada (2,5):** Design focado na usabilidade do motorista.

###  Requisitos ainda não Implementados
*   ** Persistência em Banco de Dados Real (SQL/NoSQL)
*   ** Autenticação de Usuários Real
*   ** APP do Administrador para Sincronização em Tempo Real (Painel do Patrão)


##  Arquitetura do Projeto (MVC)

Para garantir a organização e facilidade de manutenção pedida na avaliação:
- **Models (`lib/models`): Definição da estrutura do log de transporte.
- **Views (`lib/screens`): Interfaces de usuário separadas por funcionalidade.
- **Services/Controllers (`lib/services`): Lógica de negócio, incluindo:
    - `GpsService`: Gerenciamento de geolocalização.
    - `LogService`: Persistência local e exportação de dados (Excel/CSV/TXT).
    - `ScannerService`: Integração com a câmera para leitura de QR Code.

---

##  Como Executar

1. **Pré-requisitos:** Flutter SDK instalado e configurado.
2. **Dependências:** Execute `flutter pub get` na raiz do projeto.
3. **Execução:** 
   ```bash
   flutter run

## Como Usar 
1. Tela de Login (Home)
É o ponto de entrada. Como o foco da Parte 1 é a identificação e tratamento de variáveis, ela serve para coletar o nome do operador.
Ações:
O escolhe o nome e clica em "ENTRAR". 

Tratamento de Dados:
O nome é salvo em SharedPreferences para ser usado nos logs e relatórios.
Possível Erro:

2. Tela de Preparação de Rota (RotaScreen)

Ações:
Modo Scanner: Abre a câmera para ler o QR Code (JSON). formato do json ({"id": "01", "destino": "Upa Santa Paula", "lat": -25.051245, "lng": -50.131844}) 
link recomendado para o QR code "https://quickchart.io/qr-code-api/?gad_source=1&gad_campaignid=20924226900&gclid=CjwKCAjwtcHPBhADEiwAWo3sJiLIgjGpDv2iAOx91drWDdkBWpi24WeYHeKLcWNmTAMtOq54zG2OmBoCqgkQAvD_BwE"
Modo Manual: O usuário digita o ID da amostra e seleciona a origem via listBox (pois para a aplicação em questão os locais são fixos).

Iniciar Corrida: Valida os dados e abre o mapa.
Possíveis Erros e Tratamento:
GPS Desativado: O app tenta buscar a localização; se falhar, ele exibe um aviso ou permite seleção manual para não travar o fluxo.
QR Code Inválido: Se o scanner ler algo que não seja o JSON esperado (id, lat, lng), o código captura o erro (try-catch) e avisa que o formato é inválido.
Validação de Formulário: Se o ID da amostra estiver vazio no modo manual, o GlobalKey<FormState> impede o avanço e mostra a mensagem de erro em vermelho.
Botão Cancelar: Opção de cancelar o scanner caso o usuário desista de ler o código.

3. Tela de Rastreamento em Tempo Real (RastreamentoScreen)
Aqui acontece a execução do serviço e a auditoria de tempo.

Ações:
Cálculo de Rota: O app consome a API para dizer a distância e o tempo estimado.
Botão Finalizar: Encerra a corrida e registra os tempos.
Possíveis Erros e Ações:
Distância do Destino: O app pode verificar se o motoboy está realmente no laboratório antes de permitir finalizar (ajuda a evitar fraudes de horário).
Interrupção do GPS: Se o sinal cair, o app mantém o último ponto conhecido para não quebrar a interface.

4. Tela de Relatórios e Auditoria (RelatorioScreen)

Ações:
Visualização da Timeline: Mostra quem foi o motorista, qual a amostra, e os horários exatos.
Cálculo de Performance: O app subtrai o tempo de deslocamento do tempo total para isolar o Tempo Ocioso (espera no laboratório).
Exportação: Botões para gerar arquivos Excel, CSV ou TXT.
Tratamento de Dados:
Persistência Local: Mesmo se fechar o app, os dados continuam lá porque usamos o SharedPreferences.
Possível Erro:
Lista Vazia: Se não houver entregas, o app exibe uma mensagem: "Nenhum registro encontrado".
