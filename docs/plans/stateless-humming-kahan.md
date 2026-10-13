# Modernização completa da interface do Alt-F

## Contexto

Modernizar **toda a interface administrativa** para o D-Link DNS-320L A3, conforme o escopo escolhido, sem adicionar serviços residentes ou aumentar desnecessariamente a carga do NAS. A base continua sendo BusyBox `httpd`, CGI em shell e arquivos estáticos locais. A plataforma usa a configuração `dns325`/ARMv5; os testes no `docker-dev` x86_64 não substituem a validação final nessa arquitetura.

O resultado esperado é uma interface responsiva, consistente e acessível, sem frames de navegação, mantendo as funções atuais de armazenamento, usuários, serviços, pacotes e configurações. Não fazem parte deste trabalho atualizações de kernel/pacotes, tradução da interface, uma API nova ou uma revisão geral da autenticação.

## Arquitetura recomendada

- HTML gerado no servidor e navegação convencional entre CGI. Formulários continuam sendo enviados pelo navegador; sem SPA, interceptação global de POST, frontend com servidor próprio, CDN, fontes externas ou dependências de produção novas.
- Navegação HTML semântica gerada a partir dos arquivos `.men` existentes. JavaScript vanilla apenas para menu móvel, tooltips, favoritos e aprimoramentos de usabilidade. Links e formulários comuns continuam utilizáveis sem o JavaScript novo; preservar funcionalidades antigas que já dependem dele, como o desafio de login.
- Cabeçalho/fechamento compartilhados, com modos explícitos de página completa e HTML mínimo. Fragmentos de status, redirecionamentos, downloads e respostas binárias não recebem o shell administrativo.
- Modernizar o tema padrão existente `dull`, mantendo o nome, o symlink `default.thm` e a seleção atual. Conservar `demo`, que herda o estilo base, e adicionar `classic.thm` com o CSS antigo para retorno visual. Esse retorno **não** restaura o frameset; todos os temas distribuídos devem funcionar com navegação sem frames.
- CSS de layout e comportamento comuns independentes do tema. Separar novos helpers shell e módulos JavaScript por responsabilidade, sem expandir indiscriminadamente o grande `common.sh`.

## Pontos de reutilização e contratos

- `customroot/usr/www/cgi-bin/common.sh`: `html_header()` (381), `write_header()` (793), `load_thm()` (777), `menu_setup()` (756), controles compartilhados, `gotopage()` (599), `check_cookie()` (622), `download_file()` (575) e `embed_page()` (693).
- `customroot/usr/www/cgi-bin/login.cgi` / `login_proc.cgi`: conservar nomes de campos, POST, desafio MD5/salt, cookie `ALTFID`, expiração de 30 minutos e retorno `from_url`. Só adaptar a navegação necessária à retirada dos frames.
- **`status.cgi` atualmente não chama `check_cookie()`.** Preservar essa semântica pública; não mudar permissões como efeito colateral visual. Seu ramo `?refresh=` (595–617) deve continuar separado da página principal, sem menus e sem novos timers/requisições.
- `sys_utils.cgi` / `sys_utils_proc.cgi`: reutilizar seleção de temas e preferências `TOP_MENU`/`SIDE_MENU`, evitando que as duas navegações sejam desativadas simultaneamente.
- Preservar `action`, `method`, `enctype`, nomes/valores dos campos, parâmetros de query, confirmações e resultados dos handlers. Algumas páginas de apresentação também escrevem configurações: não executá-las no host durante testes.

## Etapas de implementação

### 1. Caracterização e ambiente seguro

Criar testes em `scripts/test/ui/`, separados do antigo teste de compilação de pacotes. Inventariar todas as páginas renderizadas e entradas `.men`, incluindo páginas auxiliares que não aparecem nos menus; classificar HTML completo, HTML mínimo, fragmentos, redirecionamentos, uploads/downloads e integrações externas.

Registrar contratos de formulários e respostas antes das mudanças. Montar um harness descartável no **`docker-dev`**, com BusyBox/ash, arquivos de configuração sintéticos e stubs explícitos para comandos de sistema. Testar handlers reais somente depois de revisar e autorizar individualmente seu uso no sandbox; simular as operações destrutivas e os serviços externos.

Sem dispositivos reais, Docker socket, privilégios, mounts de configurações do host/NAS ou acesso à produção. O código deve entrar pelo contexto de build/cópia: um bind mount de caminho local não pode ser presumido disponível no host Docker remoto. Dependências de navegador ficam apenas no harness de desenvolvimento. Configurar `TZ=America/Sao_Paulo` nos containers.

### 2. Shell e navegação sem frames

Substituir o frameset de `customroot/usr/www/index.html` por uma entrada leve para a rota de status, sem perder o redirecionamento do primeiro boot. Manter `index.cgi` como entrada compatível de navegação normal.

Extrair novos helpers de apresentação para módulos focados em `cgi-bin/` (por exemplo, `ui_shell.sh` e `ui_navigation.sh`), carregados pelo mecanismo existente de `common.sh`. Reutilizar os arquivos `.men`, inclusive favoritos e menus condicionais, em vez de duplicar a árvore de rotas.

Adicionar HTML5, viewport móvel, link para pular a navegação, landmarks, título/ajuda/aviso de configurações não salvas e fechamento compartilhado `write_footer()`. Conservar o argumento de `onload` de `write_header()` e os estilos específicos `LOCAL_STYLE`.

Trocar o uso de `parent.frames` em `check_cookie()` por navegação HTTP de página inteira, preservando o endereço original e sua query após login. Codificar/validar o destino local ao construir esse redirecionamento; não inserir URI bruta em JavaScript. Não mudar o mecanismo de sessão ou o escopo de endpoints protegidos.

### 3. Tema responsivo e componentes

Reorganizar `scripts/dull/dull.css` e os comportamentos de `dull.js` em assets pequenos por responsabilidade sob `scripts/ui/`, preservando os nomes chamados pelos atributos HTML existentes (`popUp`, `popDown`, favoritos etc.). Ajustar os manifests `dull.thm`/`demo.thm` para não carregar implementações duplicadas. Adicionar `classic.thm` e seu CSS de fallback.

Usar fontes do sistema, cores de alto contraste, controles legíveis, foco visível e alvos de toque adequados. Navegação superior/lateral deve funcionar na mesma página; no celular, recolher sem ocultar definitivamente as rotas. Tooltips precisam funcionar por foco e toque, não apenas hover.

Distinguir tabelas de layout de tabelas de dados. Adaptar formulários para telas estreitas; tabelas densas mantêm todas as colunas e ações dentro de uma região com rolagem horizontal acessível. Não esconder dados para fazê-los caber. Preservar as métricas e barras existentes, sem adicionar gráficos ou consultas novas.

### 4. Migrar toda a superfície administrativa

Migrar as páginas HTML para a estrutura e o fechamento compartilhados, em lotes por domínio: status/login; sistema/rede; discos/RAID/LVM; usuários/permissões/compartilhamentos; serviços; pacotes/integrações. As etapas são organização do trabalho, não redução do escopo final.

Exemplos representativos: `status.cgi`, `smb.cgi`, `services.cgi`, `diskwiz.cgi`, `usersgroups.cgi`, `packages_ipkg.cgi`, `settings.cgi`, `firmware.cgi` e `certs.cgi`. Incluir diálogos de seleção, ajuda e respostas de erro/espera; não transformar todos os `_proc.cgi` em páginas completas.

Adicionar classes, labels e wrappers locais onde o CSS compartilhado não basta. Manter ordem e semântica dos controles. Preservar o HTML mínimo do refresh de status e seus intervalos atuais (11–59 segundos), sem acrescentar polling. Ajustes desse ramo devem ser limitados à apresentação e compatibilidade, sem novas restrições de acesso.

### 5. Compatibilidade de fluxos especiais

Adaptar dependências de frames em `bookmark.cgi`, `sys_utils_proc.cgi`, `http_proc.cgi`, `host_proc.cgi` e `twonky.cgi`, além dos helpers de favoritos. Preservar mudanças de endereço/protocolo, retorno após POST, primeiro boot, logout e histórico do navegador.

Manter os iframes intencionais de `embed_page()` para interfaces externas; a retirada dos frames de navegação não exige eliminá-los. Preservar uploads multipart e cabeçalhos/conteúdo de downloads, sem roteamento via fetch da nova UI. Temas de terceiros que dependam diretamente dos frames não têm compatibilidade automática garantida; documentar a migração necessária sem remover uploads/seleção existentes.

### 6. Empacotamento e documentação

Atualizar `rootfsfiles-base.lst` para incluir os novos helpers, manifests e assets e tratar arquivos substituídos. Verificar propriedade de arquivos em `ipkgfiles/` antes de alterar manifests de pacotes; não adicionar infraestrutura de teste ao firmware.

Preservar a instalação do overlay via `configfs`, sem modificar sua lógica não relacionada. Adicionar `.playwright-mcp/` ao `.gitignore`; todas as capturas devem ficar nessa pasta.

Documentar comandos de teste, escolha/fallback de tema e limitações em `docs/ui-development.md`. Atualizar as páginas de ajuda impactadas. Não alterar o Nginx Proxy Manager programaticamente; caso seja usado para o preview, fornecer instruções manuais. Preservar a alteração preexistente de `CLAUDE.md`.

## Verificação e critérios de aceite

Disponibilizar um runner documentado, `scripts/test/ui/run_ui_checks.sh`, com suítes `static`, `render`, `browser` e `budget`, executadas no `docker-dev`.

- **Static:** sintaxe de todos os shell/CGI alterados com BusyBox ash; assets/manifests/rotas existentes; nenhuma dependência residual do frameset nos arquivos distribuídos; contratos de formulários preservados. Validar documentação com ferramenta de lint apenas no ambiente de desenvolvimento.
- **Render:** fixtures cobrindo estados vazios, um e muitos itens; seções condicionais; textos longos/caracteres especiais; páginas completas e respostas especiais com cabeçalhos corretos. Usar os helpers reais, não cópias da nova interface dentro dos mocks.
- **Browser:** Playwright com o servidor BusyBox do harness e artefatos em `.playwright-mcp/`. Todas as telas renderizáveis devem ter ao menos um smoke test ou cenário explícito de integração indisponível. Cobrir menus/favoritos, teclado, login correto/incorreto, expiração, primeiro boot, links com query, reload/back/forward, POST, multipart, downloads, seleção de temas e embeds simulados. Não enviar operações de disco/flash ou reinícios a hardware real.
- **Responsividade:** validar 360, 768 e 1280 px; sem overflow horizontal da página, perda de dados/ações ou menus inacessíveis. Tabelas largas podem ter rolagem própria. Fazer avaliação automatizada de acessibilidade e checagem manual dos fluxos principais.
- **Budget:** CSS+JS de produção efetivamente carregados pelo tema padrão, incluindo recursos compartilhados e scripts inline existentes, até **100 KiB brutos por página**. Medir a linha de base antes de adicionar código; diminuir duplicação se necessário. Sem aumentar o polling, introduzir processo residente ou carregar recursos de rede externos na UI interna.
- **Firmware:** validar o inventário e depois construir a imagem atual `dns325` no ambiente de desenvolvimento apropriado. Respeitar os limites existentes de 3 MiB para kernel, 3 MiB para initramfs e 100 MiB para imagem extra em `mkfw.sh`; não aumentar limites para acomodar a UI. Compilar/usar a toolchain ARMv5 correta.
- **Validação alvo:** se houver QEMU, usar uma imagem gerada do checkout modificado ou instalar explicitamente o overlay novo; `qemu-Alt-F.sh` baixa um release e sozinho não testa estas mudanças. Medir RAM/CPU e fazer smoke test no DNS-320L A3 antes de recomendar instalação definitiva. QEMU/x86 não comprovam limites de hardware nem desempenho real.

A entrega só é considerada completa quando toda a superfície administrativa estiver coberta e as verificações disponíveis tiverem passado. Informar separadamente qualquer etapa bloqueada por toolchain, ambiente ou indisponibilidade do A3. Gravar firmware em equipamento real, atualizar bootloader ou operar produção exige autorização específica e não faz parte desta implementação.
