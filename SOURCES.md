# Sources officielles — vérification initiale 2026-10-02, adaptation multicomptes 2026-10-11

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
| GitLab CLI | `GLab.GLab` | [Installation officielle GitLab](https://gitlab.com/gitlab-org/cli/-/blob/main/docs/installation_options.md), [catalogue Microsoft : scope machine /ALLUSERS](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/GLab/GLab) |
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

## Adaptation multicomptes

- [WinGet install / scope](https://learn.microsoft.com/en-us/windows/package-manager/winget/install) : sélection explicite machine/utilisateur, sans désactivation des hashes ni repli de périmètre.
- [Windows Terminal distributions](https://learn.microsoft.com/en-us/windows/terminal/distributions) : distribution MSIX personnelle retenue en phase 30. Le bootstrap n'utilise pas le mode portable qui partagerait les paramètres près des binaires.
- [uv manifest](https://github.com/microsoft/winget-pkgs/blob/master/manifests/a/astral-sh/uv/0.12.13/astral-sh.uv.installer.yaml) : archive officielle avec exécutables portables uv/uvx ; installation machine demandée à WinGet.
- [WinGet : permissions des archives portables machine](https://github.com/microsoft/winget-cli/issues/2993), [icacls Microsoft](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/icacls) : correction limitée au paquet uv, ajout du droit Users RX et vérification, sans modification générale de Program Files/WinGet.
- [Docker CLI package](https://github.com/microsoft/winget-pkgs/tree/master/manifests/d/Docker/DockerCLI) : client autonome pour RemoteCLI ; pas de service dockerd enregistré.
- [Docker Windows installation et droits](https://docs.docker.com/desktop/setup/install/windows-install/) : mode all-users, prérequis WSL2, conditions d'utilisation de docker-users et limites du support des VM.
- [Docker SSH contexts](https://docs.docker.com/engine/security/protect-access/) : transport SSH et protection du socket ; ne pas exposer TCP 2375.
- [Oracle SQLcl](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/download/) et [documentation par version](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/index.html) : distribution officielle, exigences Java à sélectionner ensemble. Procédure manuelle reproductible dans docs/ORACLE.md.
- [Oracle Developer Tools for VS Code](https://docs.oracle.com/en/database/oracle/oracle-database/21/xeinw/introduction.html) : extension Oracle.oracledevtools demandée, distincte de SQL Developer for VS Code.
- [OpenRouter](https://openrouter.ai/docs/quickstart) : URL API et intégration fournisseur ; aucune clé incluse dans le bootstrap.

Les paquets restent soumis à l'évolution du catalogue. Les tests automatisés simulent les installateurs et ne remplacent pas la qualification des manifestes effectivement sélectionnés dans une VM Windows. Les fonctionnalités d'auto-update propres aux produits peuvent différer de l'idempotence du bootstrap ; prévoir leur maintenance séparément.
