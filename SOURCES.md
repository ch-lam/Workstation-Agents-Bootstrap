# Sources officielles vérifiées — 2026-10-02

Les IDs sont ceux du catalogue Microsoft WinGet ou ceux explicitement documentés par l'éditeur. Les versions de ce catalogue évoluent ; les scripts vérifient l'ID exact avant une installation et conservent les contrôles d'intégrité WinGet. Le catalogue communautaire hébergé par Microsoft n'est pas une certification Microsoft de chaque éditeur.

| Outil | Méthode retenue | Source primaire |
|---|---|---|
| PowerShell 7 stable | `Microsoft.PowerShell`, `--installer-type wix` pour MSI | [Microsoft Learn](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows) |
| Windows Terminal stable | `Microsoft.WindowsTerminal` | [Microsoft Learn](https://learn.microsoft.com/en-us/shows/open-at-microsoft/introduction-to-windows-terminal), [distributions](https://learn.microsoft.com/en-us/windows/terminal/distributions) |
| Git for Windows | `Git.Git` | [Git officiel](https://git-scm.com/install/windows) |
| VS Code | `Microsoft.VisualStudioCode` | [installation Windows](https://code.visualstudio.com/docs/setup/windows), [configuration développeur Microsoft et IDs](https://github.com/microsoft/WindowsDeveloperConfig/blob/main/windows-dev-config/README.md) |
| Node.js LTS | `OpenJS.NodeJS.LTS` ; minimum 22 ; LTS actuelle 24 à la vérification | [cycles officiels Node](https://nodejs.org/en/about/previous-releases), [IDs Microsoft](https://github.com/microsoft/WindowsDeveloperConfig/blob/main/windows-dev-config/README.md) |
| Python | `Python.Python.3.14` | [guide Microsoft Windows Python](https://github.com/MicrosoftDocs/windows-dev-docs/blob/docs/hub/dev-environment/python.md) |
| uv et uvx | `astral-sh.uv` ; uvx est livré avec uv | [Astral installation](https://docs.astral.sh/uv/getting-started/installation/), [outils uv](https://docs.astral.sh/uv/guides/tools/) |
| GitHub CLI | `GitHub.cli` | [GitHub CLI officiel](https://github.com/cli/cli#installation), [IDs Microsoft](https://github.com/microsoft/WindowsDeveloperConfig/blob/main/windows-dev-config/README.md) |
| Docker Desktop | `Docker.DockerDesktop` | [prérequis/installation Docker](https://docs.docker.com/desktop/setup/install/windows-install/), [manifest Microsoft](https://github.com/microsoft/winget-pkgs/blob/master/manifests/d/Docker/DockerDesktop/4.67.0/Docker.DockerDesktop.yaml) |
| Sysinternals Suite | `Microsoft.Sysinternals.Suite` | [catalogue Microsoft](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/Sysinternals/Suite), [suite Microsoft](https://learn.microsoft.com/en-us/sysinternals/downloads/sysinternals-suite) |
| Codex CLI | `npm install -g @openai/codex` | [CLI officielle](https://learn.chatgpt.com/docs/codex/cli), [installation npm dans le cookbook officiel](https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex), [Windows](https://learn.chatgpt.com/docs/windows/windows-sandbox) |
| Claude Code CLI | WinGet `Anthropic.ClaudeCode` natif | [Anthropic setup](https://code.claude.com/docs/en/setup) |
| Grok CLI officiel xAI | `npm install -g @xai-official/grok` ; Windows x64 | [README officiel xAI](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/npm/grok/README.md), [docs xAI / distribution npm](https://docs.x.ai/build/enterprise), [CLI/login](https://docs.x.ai/build/cli/reference) |

PowerShell 7.6 utilise MSIX par défaut via WinGet ; la documentation permet encore MSI via `--installer-type wix`. Ce choix pourra être revisité si une future majeure abandonne MSI. Le playbook n'utilise pas le canal Preview.

Les versions Node 22 et 24 sont LTS à la date de recherche ; Node 26 est encore Current. Le contrôle `process.release.lts` évite de prendre automatiquement toute majeure paire pour une LTS. Le cycle de support doit aussi être revu lors d'une réutilisation future.

Claude propose l'installateur natif PowerShell et WinGet ; le playbook choisit WinGet pour éviter l'exécution directe d'un script distant. Son installation npm reste documentée mais n'est pas utilisée. Git for Windows fournit Git Bash utile aux outils Claude. Claude natif Windows n'offre pas le même sandbox que WSL2 : vérifier les permissions demandées dans chaque agent ; installer WSL ne déplace pas les CLI Windows dans WSL.

## Paramétrage Windows et extensions

- [WSL installation](https://learn.microsoft.com/en-us/windows/wsl/install) et [commandes](https://learn.microsoft.com/en-us/windows/wsl/basic-commands) : installation, update, default version 2.
- [powercfg](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options) : délais AC du plan actif.
- [Windows Time](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings) : status, stripchart et resync ; la politique existante reste intacte.
- [VS Code CLI/extension marketplace](https://code.visualstudio.com/docs/configure/extensions/extension-marketplace) : `--list-extensions`, `--install-extension`.
- Extensions : [GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens), [Container Tools](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-containers), [PowerShell](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell), [Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python), [ESLint](https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint), [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode), [YAML](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml).

Pour réutiliser ce playbook plusieurs mois plus tard, relire ces liens et `winget show --id <ID> --exact --source winget`, notamment les OS supportés, les licences et les modalités d'authentification.

Windows Update : API officielle IUpdateSearcher.Search (https://learn.microsoft.com/en-us/windows/win32/api/wuapi/nf-wuapi-iupdatesearcher-search), criteres IsInstalled=0 and IsHidden=0 ; BrowseOnly indique les mises a jour facultatives. OperationResultCode (https://learn.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode) : seul orcSucceeded=2 est traite comme recherche complete.
