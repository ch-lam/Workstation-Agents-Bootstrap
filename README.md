# Workstation d’agents — bootstrap Windows 11 Pro

Ce bootstrap prépare Windows, les outils de développement et les CLI d’agents. Timon et les autres orchestrateurs s’installent séparément. Aucun compte Windows, mot de passe, token, clé SSH ou identifiant Oracle n’est créé ou transféré.

## Parcours : un seul changement de compte

| Bloc | Compte | Phases |
|---|---|---|
| Diagnostic facultatif | Administrateur, ou utilisateur standard | 00 en CheckOnly |
| Préparation système | Administrateur | **10 → 20 → 50** |
| Préparation personnelle | Compte standard cible | **30 → 40 → 60**, connexions, puis **70** |

Terminez tout le bloc administrateur, y compris ses éventuels redémarrages, avant de passer au compte standard. Aucun retour administrateur n’est prévu dans le parcours nominal. Un redémarrage n’implique pas un changement de compte. Le compte standard n’est jamais ajouté automatiquement aux Administrators ni à docker-users.

Windows PowerShell 5.1 peut lancer le bloc système. Ouvrez ensuite une nouvelle session PowerShell 7 sous le compte standard. Une élévation UAC avec les identifiants d’un autre compte travaille dans le profil de cet administrateur, jamais dans celui du compte standard.

## Préparer les fichiers et la configuration

Le dépôt doit être lisible par les deux comptes. Pour toute exécution élevée, utilisez une copie vérifiée dans un emplacement dont les utilisateurs standards ne peuvent modifier ni les scripts ni les fichiers de configuration système. Ne rendez pas le dépôt inscriptible par tous pour résoudre un problème de logs. Une copie personnelle de la configuration peut servir aux réglages Git et aux contextes SSH ; elle doit conserver les choix système du bloc administrateur.

Les journaux sont dans `%LOCALAPPDATA%\Workstation-Agents-Bootstrap\machine-logs` pour les phases 10/20/50, et `user-logs` pour les autres phases, sous le compte exécutant. Ils ne dépendent plus d’un répertoire inscriptible dans le dépôt.

```powershell
.\Configure-Bootstrap.ps1
# Ou consulter sans enregistrer :
.\Configure-Bootstrap.ps1 -Action Configuration -PreviewOnly
```

Le wizard conserve les nouvelles sections existantes. Pour Oracle et les contextes SSH, éditez le PSD1 : l’exemple [config.both.psd1](examples/config.both.psd1) est destiné à une station combinant moteurs local et distants. Copiez-le en `config.local.psd1`, puis renseignez vos paramètres. Les clés absentes reçoivent les valeurs par défaut de [config.psd1](config.psd1).

Sans `-ConfigPath`, chaque phase utilise `config.local.psd1` à côté des scripts s’il existe, sinon `config.psd1`. Les chemins complets des commandes de continuation désignent exactement le fichier sélectionné.

## Bloc administrateur : 10, 20, 50

Si Oracle est activé, préparez SQLcl et son JDK selon [ORACLE.md](docs/ORACLE.md) avant la phase 20. Pour Docker Desktop, vérifiez les prérequis de virtualisation et le service LanmanServer avant de quitter ce compte.

```powershell
.\Invoke-Bootstrap.ps1 -Stage Preflight -ConfigPath .\config.local.psd1
.\Invoke-Bootstrap.ps1 -Stage Administrator -ConfigPath .\config.local.psd1
```

- **10** : alimentation sur secteur si demandée ; WSL/VirtualMachinePlatform uniquement en LocalDesktop/Both ; resynchronisation de l’heure seulement si demandée.
- **20** : applications machine, Python, uv/uvx et préparation des chemins Oracle. Contrôle de la résolution des outils système.
- **50** : client SSH si distant ; Docker CLI seul ou Docker Desktop/WSL selon le mode ; contrôle du socle avant le passage de compte. Aucun serveur SSH installé, aucune ouverture de port.

Le code de sortie **3010** signifie redémarrage requis. Redémarrez et reprenez la commande affichée sous l’administrateur. Les installations conformes restent en place, sans mise à jour implicite. Les erreurs de périmètre doivent être résolues dans ce bloc, sans duplication ni désinstallation automatique.

LanmanServer doit être actif et en démarrage automatique pour le profil Desktop. Le bootstrap signale un prérequis manquant sans modifier ce service réseau. Il ne change ni réseau, ni VPN, ni RDP, ni pare-feu.

## Bloc utilisateur : 30, 40, 60, connexions, 70

Changez une seule fois de compte Windows. Sous le compte standard, ouvrez PowerShell 7, revenez dans le dépôt et utilisez la configuration appropriée.

```powershell
.\Invoke-Bootstrap.ps1 -Stage User -ConfigPath .\config.local.psd1
```

- **30** : contrôle des outils machine depuis ce compte, installation/enregistrement personnel de Windows Terminal, contrôle Python/uv/uvx et Oracle.
- **40** : Codex et Grok via npm personnel, Claude Code natif via WinGet utilisateur. Les paramètres et connexions restent propres à ce compte.
- **60** : extensions VS Code, Git personnel, contextes Docker SSH déclarés et instructions OpenRouter.

Pour LocalDesktop/Both, lancez Docker Desktop sous ce compte, examinez sa licence, choisissez le moteur Linux WSL2 et attendez son démarrage. Aucune distribution Linux personnelle n’est imposée. Le bootstrap ne change pas le contexte actif ni le défaut WSL de l’administrateur.

Connectez Claude ou Codex hors des journaux et testez une vraie conversation. GitHub et Grok se connectent séparément.

```powershell
codex login
codex
# Alternative : lancer claude et suivre son parcours de connexion.
.\Configure-Bootstrap.ps1 -Action ConfirmLogin -ConfigPath .\config.local.psd1
.\Invoke-Bootstrap.ps1 -Phase '70' -ConfigPath .\config.local.psd1
```

La confirmation est enregistrée dans `%LOCALAPPDATA%\Workstation-Agents-Bootstrap\backend-confirmation.psd1`, liée au SID courant. C’est une déclaration humaine, pas une lecture des tokens. Un ancien `BackendLoginConfirmed=true` partagé ne valide pas le nouveau compte : confirmez à nouveau une fois, sans réinstaller.

La phase 70 vérifie le socle, les extensions, les chemins et les moteurs sélectionnés. Son rapport de succès est dans `user-logs\validation-success.json`. Un succès avec une liste distante vide ne certifie aucun serveur distant ; les résultats MANUAL/WARN doivent être lus.

## Politique d’installation

| Outils | Périmètre |
|---|---|
| PowerShell 7 (MSI), Git, GitHub CLI, VS Code, Node LTS, Python | Machine, `--scope machine` |
| uv/uvx, Sysinternals, Docker CLI seul | Paquets WinGet, périmètre machine explicite |
| Docker Desktop | Machine, sans seconde copie du CLI en Both |
| Windows Terminal | Exception MSIX : enregistrement/installation sous le compte standard, phase 30 |
| Codex, Grok, Claude, extensions, Git/SSH personnels | Utilisateur |
| SQLcl et JDK | Distribution officielle préparée sous Program Files par l’administrateur |

L’exception Terminal utilise la distribution packagée officielle, qui ne nécessite pas d’élévation. Le bootstrap ne prétend pas que l’installation MSIX du compte administrateur vaut pour tous les comptes.

Les contrôles WinGet distinguent les périmètres. Si un paquet n’existe que dans un autre périmètre visible, l’installation s’arrête pour une migration explicite. Les inventaires ne permettent pas de certifier tous les profils Windows hors session : le contrôle final dans le compte cible reste indispensable. Une installation personnalisée hors des racines système est signalée ; ne déplacez pas automatiquement ses fichiers.

Les paquets portables installés machine peuvent avoir des liens dans Program Files\WinGet\Links. Ne donnez pas aux utilisateurs le droit de modifier ces binaires. Certains outils Sysinternals nécessitent une élévation pour leurs fonctions avancées ; leur accessibilité ne leur confère pas ces droits.

## Docker local et distant

| DockerMode | Préparation locale | Distant |
|---|---|---|
| None | Aucune | Aucune |
| LocalDesktop | Desktop + WSL2 | Contextes existants conservés |
| RemoteCLI | CLI seul, pas de WSL/daemon | SSH et contextes déclarés |
| Both | Desktop + son CLI + WSL2 | SSH et contextes déclarés |

```powershell
@{
    DockerMode = 'Both'
    DockerLocalContext = 'desktop-linux'
    DockerRemoteContexts = @(
        @{ Name = 'remote-dev'; Host = 'ssh://developer@docker-host:22'; Required = $true }
    )
}
```

Le nom local est configurable, mais son endpoint doit être un named pipe Windows. Un serveur distant ne peut pas satisfaire le contrôle local. Chaque moteur est interrogé par `--context`, avec un délai de 30 secondes par sonde. Les variables DOCKER_HOST/DOCKER_CONTEXT présentes sont signalées sans afficher leur valeur.

Les noms default, desktop-linux et celui du contexte local sont réservés. Un contexte existant dont l’endpoint diffère n’est ni remplacé ni supprimé. `Required=false` transforme un échec distant en avertissement. Aucun paramètre distant : aucun contexte créé, aucune connexion tentée.

```powershell
docker context ls
docker context use default
docker context use remote-dev
docker --context remote-dev ps
```

`default` n’est pas nécessairement le moteur Linux Desktop : inspectez ses paramètres. Docker Desktop peut sélectionner son contexte lors de son premier lancement ; le bootstrap, lui, ne bascule pas les contextes. Les volumes bind mount distants référencent les chemins de l’hôte Docker, pas le disque Windows client.

Préparez manuellement SSH sous l’utilisateur : clé protégée ou autre authentification appropriée, empreinte du serveur vérifiée et accès autorisé au socket Docker. Aucun `StrictHostKeyChecking=no`, aucune clé générée, aucun TCP 2375. L’accès au daemon distant peut équivaloir à un accès root sur le serveur.

Sur Windows, docker-users est un droit puissant, utile pour certaines fonctions Hyper-V/conteneurs Windows ; il n’est pas attribué automatiquement. Pour le seul backend Linux WSL2, la documentation Docker actuelle n’impose pas cette appartenance. Si une fonction la requiert, l’administrateur doit autoriser nominativement le compte avant le passage de session, puis l’utilisateur doit se reconnecter.

En VM Proxmox/KVM, HypervisorPresent ne prouve pas la virtualisation imbriquée. Faites vérifier les extensions CPU/SLAT et le paramétrage de l’hôte ; la preuve de fonctionnement est le moteur WSL2/Desktop opérationnel dans le compte cible. Le bootstrap ne modifie pas Proxmox et ne présume pas d’un support officiel Docker pour cet hyperviseur. L’installation machine ne partage pas automatiquement les données WSL2 entre comptes.

## Migration et mises à jour

- Ancien `EnableDocker=$true` seul : LocalDesktop ; `$false` : None. Aucun distant activé implicitement.
- `DockerMode` explicite et `EnableDocker` contradictoire : erreur avant les phases. Retirez la clé ancienne après vérification.
- Les anciennes configurations sont normalisées en mémoire ; le wizard sauvegarde le schéma 2 et conserve ses sections connues.
- Python/uv auparavant personnels : inspectez vos environnements et sauvegardez les références nécessaires avant une migration manuelle vers le périmètre machine. Le bootstrap ne désinstalle rien.
- Node doit déclarer une version LTS et un majeur >=22. Vérifiez aussi le cycle de support officiel.
- Les versions Codex/Grok demandées sont vérifiées ; aucun downgrade ou upgrade implicite d’un CLI existant.
- Le préfixe npm doit se trouver dans le profil courant, être inscriptible et être présent dans le PATH utilisateur. Une correction explicitement choisie peut utiliser `npm config set prefix "$env:APPDATA\npm"` sous le compte standard. Préservez auparavant vos paquets et réglages existants ; n’élargissez jamais les ACL de Program Files.
- Mettez à jour les paquets machine dans une session administrateur de maintenance ; les outils personnels sous leur utilisateur. Exemple : `winget upgrade --id Anthropic.ClaudeCode --exact --scope user`. Les distributions SQLcl/JDK et les CLI autonomes nécessitent une politique de mise à jour explicite.

## Oracle, OpenRouter et sécurité

Voir [ORACLE.md](docs/ORACLE.md) pour SQLcl et Oracle Developer Tools for VS Code. Les wallets, TNS personnels, historiques et mots de passe restent dans le profil utilisateur ; ne les placez pas sous Program Files ni dans un PSD1 versionné.

OpenRouter est un fournisseur, pas un CLI à installer arbitrairement. `OpenRouter.Enabled` ajoute les instructions de configuration : URL API et nom de variable de secret seulement. Le client ou Timon doit être configuré séparément avec un modèle compatible. Le bootstrap ne lit ni ne stocke la valeur de la clé et ne teste pas de requête facturable.

Defender, SmartScreen, UAC et le pare-feu sont conservés. Les sorties brutes des sous-processus ne sont plus journalisées ; les erreurs donnent un code de sortie et les détails structurés passent par un filtre de secrets connus. Ne mettez jamais de secrets dans la configuration : un filtre de texte ne peut reconnaître un secret arbitraire dépourvu de contexte. Les connexions interactives se font hors bootstrap.

Un compte standard n’est pas une sandbox complète. Conservez les protections propres aux agents et limitez leurs accès aux répertoires, secrets et daemons Docker.

## Validation et diagnostic

`-CheckOnly` empêche les installations et modifications de paramètres. Il effectue des diagnostics, écrit les logs et peut interroger Windows Update/NTP/Docker. Windows Update peut rafraîchir ses métadonnées. Ce n’est pas un mode hors ligne ou sans aucune écriture.

```powershell
.\Invoke-Bootstrap.ps1 -Stage Administrator -CheckOnly -ConfigPath .\config.local.psd1
.\Invoke-Bootstrap.ps1 -Stage User -CheckOnly -ConfigPath .\config.local.psd1
```

`-Stage` et `-Phase` sont exclusifs. Sans sélection, seul le diagnostic 00 est lancé. `CheckOnly` poursuit les phases demandées pour montrer les écarts ; l’application s’arrête à la première phase échouée. Les listes de phases respectent toujours l’ordre 00,10,20,50,30,40,60,70.

Windows Update est informatif par défaut ; `-WindowsUpdateMandatory` rend bloquants les mises à jour, redémarrages et états inconnus associés. Les autres marqueurs de redémarrage restent contrôlés. Les pairs NTP existants ne sont pas remplacés ; `NtpProbeHost` ne sert qu’au diagnostic. Les contrôles de stockage portent sur les volumes système, profils, temporaires, exécutables et AdditionalStoragePaths, sans déplacer leurs données.

Si Windows bloque des fichiers téléchargés, vérifiez leur provenance avant `Unblock-File`. Si nécessaire et autorisé, utilisez `Set-ExecutionPolicy -Scope Process RemoteSigned` pour le terminal courant ; les stratégies d’entreprise restent prioritaires.

## Tests

```powershell
pwsh -NoProfile -File .\tests\Run-Tests.ps1
powershell -NoProfile -File .\tests\Run-Tests.ps1
```

Les tests utilisent des doubles de commandes et des fichiers temporaires vérifiés. Aucun bootstrap réel, installation Windows, login ou connexion Docker n’est lancé. La CI exécute ces scripts sur Windows en PowerShell 5.1 et 7. Voir [ACCEPTANCE.md](docs/ACCEPTANCE.md) pour la qualification réelle multicomptes, indispensable avant déploiement.
