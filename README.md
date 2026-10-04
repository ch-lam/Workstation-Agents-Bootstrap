# Workstation d’agents — bootstrap Windows 11 Pro

Ce projet prépare un poste Windows pour utiliser des outils de développement et des agents en ligne de commande. Il installe les applications communes, configure les prérequis Windows et permet de contrôler que l’ensemble fonctionne.

Un *harness* est l’application qui organise et pilote les agents. Son installation et sa configuration se font séparément, selon sa propre documentation. Le bootstrap prépare uniquement le socle sur lequel vous pourrez l’utiliser.

Le parcours comprend un diagnostic initial, les installations nécessitant les droits administrateur, la configuration du compte utilisateur, puis une validation finale. Un assistant pose les questions de configuration et les scripts affichent les commandes à copier-coller pour continuer.

## Ce qui est préparé

- PowerShell 7 et Windows Terminal pour les commandes et les scripts.
- Git et GitHub CLI pour travailler avec des dépôts de code.
- Visual Studio Code et les extensions configurées.
- Node.js LTS, npm, Python, uv et uvx pour les outils de développement.
- Codex CLI, Claude Code CLI et Grok CLI.
- Sysinternals Suite pour le diagnostic du poste.
- Docker Desktop et WSL2, si cette option est activée.
- Les réglages d’alimentation sur secteur, les contrôles de l’heure et de l’espace disque.

Le bootstrap ne crée pas de dossier de projets ni de sas de livraison. Les logiciels utilisent les destinations de leurs installateurs. Aucun compte, token ou clé API n’est inclus dans le dépôt.

## Avant de commencer

Le profil prévu est **Windows 11 Pro x64**, avec WinGet disponible. Le diagnostic contrôle au minimum 8 Go de RAM ; 16 Go sont recommandés par la configuration. Si Docker est activé, la virtualisation doit être disponible et activée dans le firmware de la machine.

Utilisez **le même compte Windows pendant tout le parcours**. Un terminal administrateur est une fenêtre ouverte avec « Exécuter en tant qu’administrateur » ; un terminal utilisateur normal est ouvert sans cette option. Les scripts indiquent le contexte requis. Si votre compte ne peut pas être élevé, faites préparer les opérations machine par votre administrateur et effectuez les opérations personnelles sous votre propre compte.

Placez le dépôt dans un dossier de votre choix. Toutes les commandes de ce README supposent que le terminal est ouvert dans ce dossier. Lors d’un changement de fenêtre, revenez dans le dossier avant de copier la commande suivante.

Vous pouvez commencer avec Windows PowerShell 5.1, fourni avec Windows. Le bootstrap installe PowerShell 7 ; utilisez une nouvelle fenêtre PowerShell 7 pour la partie utilisateur du parcours.

### Si Windows refuse de lancer les scripts

Si les fichiers téléchargés sont marqués comme bloqués, après avoir vérifié leur provenance et leur contenu, débloquez les scripts de ce dossier :

```powershell
Get-ChildItem -LiteralPath . -Recurse -File -Include *.ps1,*.psd1 | Unblock-File
```

Si la politique d’exécution locale empêche encore leur lancement, vous pouvez autoriser les scripts locaux **pour le terminal courant uniquement**, si votre organisation le permet :

```powershell
Set-ExecutionPolicy -Scope Process RemoteSigned
```

Cette commande ne modifie pas la politique de façon permanente. Elle peut devoir être répétée dans une nouvelle fenêtre. Les politiques d’entreprise restent prioritaires.

## Préparer la configuration

Dans un terminal utilisateur normal, lancez l’assistant :

```powershell
.\Configure-Bootstrap.ps1
```

Choisissez **« Préparer le socle »**. L’assistant demande notamment si Docker/WSL doit être préparé, si la veille sur secteur doit être désactivée, quelle identité Git utiliser et quel serveur NTP interroger pour le diagnostic de l’heure. Les options avancées permettent de choisir les extensions, le package Python et d’autres paramètres.

Appuyer sur Entrée conserve la valeur proposée. Un aperçu est présenté avant l’enregistrement dans `config.local.psd1`. Si ce fichier existe, il est sauvegardé en `.bak` avant son remplacement. L’assistant reprend les champs reconnus et ignore les champs qui ne font pas partie de la configuration du socle.

Pour consulter une configuration sans l’enregistrer :

```powershell
.\Configure-Bootstrap.ps1 -Action Configuration -PreviewOnly
```

Les valeurs par défaut sont dans [config.psd1](config.psd1). Vous pouvez aussi les consulter et modifier votre fichier local dans un éditeur. Conservez `BackendLoginConfirmed = $false` jusqu’à ce qu’une conversation réelle avec Claude ou Codex ait réussi.

**Utilisez le même fichier de configuration pour toutes les étapes.** Le paramètre `-ConfigPath` précise le fichier à employer. Sans ce paramètre, le lanceur et les scripts de phase utilisent `config.local.psd1` s’il est présent à côté des scripts, sinon `config.psd1`.

Un `config.local.psd1` placé sur le Bureau et un autre dans le dossier du dépôt sont deux fichiers différents. Les commandes proposées par l’assistant utilisent le chemin complet pour éviter cette confusion.

### Principaux paramètres

| Paramètre | Rôle |
|---|---|
| `EnableDocker` | Préparer et contrôler Docker/WSL. `false` permet un socle sans conteneurs. |
| `NoSleepOnAC` | Désactiver la veille et l’hibernation automatiques sur secteur. |
| `GitUserName`, `GitUserEmail` | Identité Git à appliquer. Une valeur vide préserve la configuration existante. |
| `GitDefaultBranch` | Nom de branche initiale à configurer dans Git. |
| `Extensions` | Extensions VS Code à installer si elles sont absentes. |
| `PythonPackage` | Identifiant WinGet du package Python. |
| `CodexVersion`, `GrokVersion` | Version npm demandée ; vide installe la version disponible quand l’outil est absent. |
| `NtpProbeHost` | Serveur utilisé pour mesurer l’écart d’heure. Ne remplace pas les pairs Windows. |
| `MaximumTimeOffsetSeconds` | Écart maximal accepté par le contrôle NTP. |
| `ResyncTime` | Demander une resynchronisation avec les sources Windows existantes pendant la préparation machine. |
| `MinimumRAMGB`, `RecommendedRAMGB` | Seuil minimal et recommandation de mémoire. |
| `MinimumSystemFreeGB` | Espace minimal sur les volumes système, profils, temporaires et exécutables. |
| `AdditionalStoragePaths` | Autres chemins dont les volumes doivent être contrôlés, par exemple des données Docker déjà déplacées. |
| `MinimumFreeGB` | Espace minimal sur les volumes des chemins supplémentaires. |
| `WindowsUpdateTimeoutSeconds` | Durée maximale de recherche Windows Update, 180 secondes par défaut. |
| `BackendLoginConfirmed` | Confirmation humaine qu’une conversation Claude ou Codex a réussi sous ce compte. |

Les emplacements configurés pour le contrôle des disques ne déplacent pas les logiciels ni leurs données. Si plusieurs usages partagent un même volume, le seuil d’espace libre le plus élevé s’applique.

## Parcours guidé : utilisateur, administrateur, puis utilisateur

Une *phase* est un script consacré à une tâche. Chaque phase porte un numéro pour pouvoir la relancer individuellement. Un *groupe*, sélectionné avec `-Stage`, enchaîne plusieurs phases dans le contexte approprié.

Pour un premier démarrage, suivez les quatre étapes ci-dessous. La section « Détail des phases » explique ensuite précisément leur rôle.

| Étape | Sélection | Phases exécutées | Terminal |
|---|---|---|---|
| Diagnostic initial | `-Stage Preflight` | `00`, avec `CheckOnly` | Utilisateur normal |
| Préparation machine | `-Stage Administrator` | `10`, `20`, `50` | Administrateur, même compte Windows |
| Préparation personnelle | `-Stage User` | `30`, `40`, `60` | Nouveau PowerShell 7 utilisateur normal |
| Connexion puis validation | Confirmation du login, puis `-Phase '70'` | `70` | Rester en utilisateur normal |

L’ordre est **00 → 10 → 20 → 50 → 30 → 40 → 60 → 70**. La préparation Docker/WSL est regroupée avec les autres opérations administrateur, avant les outils personnels.

### 1. Examiner la machine en utilisateur normal

```powershell
.\Invoke-Bootstrap.ps1 -Stage Preflight -ConfigPath .\config.local.psd1
```

Ce groupe active `CheckOnly` : il contrôle les prérequis sans lancer les installations. Sur une machine vierge, les outils qui seront installés ensuite peuvent être signalés par `WARN`. Corrigez les lignes `FAIL` avant de poursuivre.

Le terminal normal peut ne pas permettre l’inventaire complet des fonctionnalités Windows. Le script le signale ; elles seront contrôlées dans le bloc administrateur.

### 2. Préparer la machine en administrateur

Ouvrez un terminal avec **« Exécuter en tant qu’administrateur »**, sous le même compte Windows, puis revenez dans le dossier du dépôt :

```powershell
.\Invoke-Bootstrap.ps1 -Stage Administrator -ConfigPath .\config.local.psd1
```

Le bootstrap enchaîne la préparation Windows et de l’alimentation, les applications communes, puis Docker/WSL. Ces opérations sont regroupées dans ce terminal.

**Si un redémarrage est nécessaire**, le bootstrap interrompt la suite et affiche une commande de reprise. Redémarrez Windows, rouvrez un terminal administrateur sous le même compte et lancez cette commande. Le nombre `3010` est le code de sortie technique indiquant qu’un redémarrage est requis ; ce n’est pas un numéro de phase.

Les phases peuvent être relancées : elles contrôlent ce qui est déjà présent et conservent les installations conformes. Les packages existants ne sont pas mis à niveau automatiquement. Un redémarrage peut donc nécessiter de rouvrir le terminal administrateur, mais il n’est pas nécessaire d’alterner avec les phases utilisateur pendant ce bloc.

### 3. Préparer les outils personnels en utilisateur normal

Une fois le bloc administrateur terminé, fermez le terminal élevé et ouvrez un **nouveau PowerShell 7 sans élévation**. Revenez dans le dossier du dépôt :

```powershell
.\Invoke-Bootstrap.ps1 -Stage User -ConfigPath .\config.local.psd1
```

Ce groupe prépare les runtimes, les CLI d’agents, les extensions VS Code et la configuration Git. Il s’arrête ensuite pour vous laisser connecter les comptes. Aucun retour vers une phase administrateur n’est prévu dans ce bloc.

Si Docker est activé, lancez **Docker Desktop sous ce compte utilisateur normal**, terminez son premier lancement et attendez que le moteur de conteneurs Linux soit prêt. La présence de `docker.exe` ne suffit pas à prouver que le moteur fonctionne.

### 4. Connecter un CLI, confirmer puis valider

Connectez **au moins Claude OU Codex**, dans ce même terminal utilisateur normal. Lancez le CLI, suivez la connexion, posez une question simple et vérifiez que vous recevez une réponse.

Pour Claude :

```powershell
claude
```

Suivez les indications du navigateur. Si nécessaire, tapez `/login` **dans Claude**, puis faites le test de conversation. Quittez avec `/exit` pour revenir à PowerShell.

Pour Codex :

```powershell
codex login
codex
```

Terminez la connexion dans le navigateur, testez une conversation puis quittez le CLI.

Après une conversation réussie avec l’un des deux, enregistrez la confirmation :

```powershell
.\Configure-Bootstrap.ps1 -Action ConfirmLogin -ConfigPath .\config.local.psd1
```

Répondez oui à la question sur la conversation réussie, puis confirmez l’enregistrement. Cela positionne `BackendLoginConfirmed = $true`. Cette valeur est une déclaration humaine : le bootstrap ne lit pas les tokens et ne vérifie pas automatiquement la validité de la session.

GitHub CLI (`gh auth login`) et Grok (`grok login`) se connectent séparément. Leur connexion n’est pas un prérequis du contrôle de session prévu par ce bootstrap. Ne placez aucun secret dans le PSD1 ou les logs.

Vous pouvez maintenant lancer la validation finale :

```powershell
.\Invoke-Bootstrap.ps1 -Phase '70' -ConfigPath .\config.local.psd1
```

Si la confirmation du login manque, cette phase s’arrête avant les autres contrôles et affiche les commandes nécessaires. Si les contrôles passent, elle annonce **« Socle validé. Bootstrap terminé. »** Vous pouvez ensuite installer le harness de votre choix selon sa documentation.

## Détail des phases

Les commandes ci-dessous servent à comprendre ou relancer une phase isolée. Pour une installation complète, utilisez le parcours guidé ci-dessus plutôt que d’enchaîner tous les numéros dans un même terminal.

### Phase 00 — diagnostic initial

**Terminal : utilisateur normal.**

Cette phase examine Windows 11 Pro x64, la mémoire disponible, l’espace libre des volumes réellement utilisés, la virtualisation si Docker est demandé, les outils présents dans le PATH et les redémarrages en attente. Elle contrôle aussi Windows Time, l’écart NTP et Windows Update. Le profil réseau est affiché sans être modifié.

```powershell
.\Invoke-Bootstrap.ps1 -Phase '00' -CheckOnly -ConfigPath .\config.local.psd1
```

WinGet doit être disponible pour préparer les installations suivantes. Les autres outils absents peuvent être signalés en `WARN` car ils seront installés dans les phases correspondantes. Un alias Python du Windows Store est signalé comme tel ; il ne remplace pas un runtime Python utilisable.

Les volumes Windows, profils, temporaires, exécutables et chemins supplémentaires sont examinés. Le contrôle ne suppose pas que tous les logiciels sont sur C:. Chaque volume est contrôlé une fois, avec les seuils configurés.

### Phase 10 — base Windows et alimentation

**Terminal : administrateur.**

Cette phase désactive la veille et l’hibernation automatiques sur secteur si `NoSleepOnAC` est activé. Elle vérifie que les réglages ont bien été appliqués. Si Docker est activé, elle prépare les fonctionnalités Windows nécessaires à WSL et à la virtualisation.

```powershell
.\Invoke-Bootstrap.ps1 -Phase '10' -ConfigPath .\config.local.psd1
```

L’activation d’une fonctionnalité peut demander un redémarrage. Le script ne redémarre pas Windows automatiquement. Avec `ResyncTime = $true`, il demande une resynchronisation de l’heure avec les sources Windows existantes, puis contrôle le résultat.

Le réglage d’alimentation concerne uniquement la veille et l’hibernation **sur secteur**. Il ne modifie ni la batterie, ni l’écran, ni l’action du capot. Les politiques MDM/GPO peuvent imposer leurs propres réglages. Aucun dossier de travail n’est créé.

### Phase 20 — applications communes

**Terminal : administrateur.**

Cette phase installe, avec WinGet, PowerShell 7 stable, Windows Terminal, Git, VS Code, Node.js LTS, GitHub CLI et Sysinternals Suite. PowerShell est installé avec le type d’installateur MSI prévu par le script.

```powershell
.\Invoke-Bootstrap.ps1 -Phase '20' -ConfigPath .\config.local.psd1
```

Les identifiants de packages sont exacts, les contrôles d’intégrité WinGet restent actifs et les packages déjà installés sont conservés. La sortie détaillée de l’installation est disponible avec `-Verbose` et dans les logs.

Après les opérations administrateur, ouvrez une nouvelle fenêtre PowerShell 7 pour les opérations personnelles : elle bénéficiera du PATH actualisé. La suite du bloc administrateur est la préparation Docker/WSL décrite ci-dessous.

### Phase 50 — Docker et WSL

**Terminal : administrateur, avant les phases utilisateur.**

Cette phase vérifie les fonctionnalités Windows, l’absence de redémarrage bloquant, le service `LanmanServer` et WSL. Le profil exige WSL au moins en version 2.1.5. Si nécessaire, le script installe ou met à jour WSL, définit WSL2 par défaut, puis installe Docker Desktop.

```powershell
.\Invoke-Bootstrap.ps1 -Phase '50' -ConfigPath .\config.local.psd1
```

Si WSL demande un redémarrage, la phase s’arrête avant de poursuivre l’installation Docker. Reprenez après redémarrage. Aucune distribution Linux personnelle n’est imposée.

Le premier lancement de Docker Desktop, les conditions de licence et la préparation du moteur Linux se font ensuite **en utilisateur normal**. Avec `EnableDocker = $false`, la préparation et la validation de Docker/WSL sont ignorées ; les logiciels déjà présents ne sont pas désinstallés.

### Phase 30 — runtimes de développement

**Terminal : PowerShell 7 utilisateur normal.**

Cette phase vérifie Node.js : le binaire doit être une version LTS et son numéro majeur doit être au moins 22. Elle contrôle npm, installe le package Python configuré ainsi que uv, qui fournit aussi uvx, puis contrôle leur disponibilité après installation.

```powershell
.\Invoke-Bootstrap.ps1 -Phase '30' -ConfigPath .\config.local.psd1
```

Si Node est trop ancien ou n’est pas LTS, le contrôle le signale : sa mise à niveau doit être effectuée explicitement. Les scripts ne remplacent pas silencieusement une installation existante.

Si `python` ouvre le Microsoft Store, son alias peut masquer le runtime installé. Rouvrez le terminal ; si l’alias reste prioritaire, corrigez le PATH ou désactivez cet alias dans les paramètres Windows.

Les Visual Studio C++ Build Tools restent une option manuelle pour les développements qui nécessitent de compiler des modules natifs.

### Phase 40 — CLI d’agents

**Terminal : PowerShell 7 utilisateur normal.**

Cette phase installe Codex et Grok depuis leurs packages npm officiels, ainsi que Claude Code via son package WinGet natif. Elle contrôle Node/npm avant l’installation. Pour les CLI npm déjà présents, elle vérifie le package enregistré et l’emplacement du launcher afin de détecter une commande masquée ou provenant d’une autre installation.

```powershell
.\Invoke-Bootstrap.ps1 -Phase '40' -ConfigPath .\config.local.psd1
```

Les paramètres `CodexVersion` et `GrokVersion` permettent de demander une version npm précise. Lorsqu’ils sont vides, la version disponible est installée si l’outil est absent. Aucun changement implicite de version n’est effectué pour un outil déjà présent.

Les connexions aux comptes sont manuelles. La phase rappelle les commandes ; le test d’une vraie conversation Claude ou Codex doit être réalisé avant la validation finale.

### Phase 60 — configuration utilisateur

**Terminal : PowerShell 7 utilisateur normal.**

Cette phase installe les extensions VS Code absentes. La configuration par défaut comprend GitLens, Container Tools, PowerShell, Python, ESLint, Prettier et YAML.

```powershell
.\Invoke-Bootstrap.ps1 -Phase '60' -ConfigPath .\config.local.psd1
```

Elle configure aussi Git : les champs `GitUserName` et `GitUserEmail` non vides sont appliqués globalement ; une valeur vide préserve la configuration existante. `GitDefaultBranch` règle le nom de branche initiale. Renseignez votre identité avant vos premiers commits.

Choisissez PowerShell 7 comme profil par défaut de Windows Terminal si vous souhaitez l’utiliser au quotidien. Le bootstrap ne modifie pas ce choix à votre place.

À la fin de la phase, un message indique que c’est le moment de connecter Claude ou Codex et de tester une conversation. Tant que la confirmation manque, la commande suivante proposée est celle de l’assistant `ConfirmLogin`, avant de lancer la validation finale.

### Phase 70 — validation finale

**Terminal : PowerShell 7 utilisateur normal.**

Cette phase vérifie d’abord `BackendLoginConfirmed`. Si la valeur est `false`, elle s’arrête immédiatement et affiche les instructions de connexion et de confirmation.

```powershell
.\Invoke-Bootstrap.ps1 -Phase '70' -ConfigPath .\config.local.psd1
```

Elle contrôle ensuite Windows, le stockage, les redémarrages en attente, les runtimes et CLI, Windows Terminal et Sysinternals, l’alimentation sur secteur, NTP, les extensions VS Code et la présence de l’identité Git. Les champs d’identité Git absents donnent `WARN`.

Si Docker est activé, elle contrôle WSL, Docker Compose et l’accès effectif au moteur Linux. Une commande `docker --version` réussie ne remplace pas ce contrôle du moteur.

Un test de conteneur supplémentaire peut être lancé manuellement :

```powershell
docker run --rm hello-world
```

Cette commande télécharge une image si nécessaire. Elle n’est pas lancée automatiquement par le bootstrap.

Après une exécution réussie hors `CheckOnly`, un rapport `logs/validation-success.json` est enregistré et le message de fin est affiché. L’installation d’un harness est une opération distincte.

## Options d’exécution

| Option | Utilisation |
|---|---|
| `-Stage Preflight` | Diagnostic initial, avec `CheckOnly` activé automatiquement. |
| `-Stage Administrator` | Préparation machine : phases `10`, `20`, `50`. |
| `-Stage User` | Préparation personnelle : phases `30`, `40`, `60`. |
| `-Phase '00'` | Exécuter une phase ou une liste de phases précises. |
| `-ConfigPath` | Choisir le fichier de configuration. |
| `-CheckOnly` | Contrôler et présenter les actions sans appliquer les installations ou réglages. |
| `-Verbose` | Afficher les détails techniques, chemins et sorties des commandes. |
| `-WindowsUpdateMandatory` | Rendre bloquants les résultats Windows Update qui exigent une action ou ne peuvent pas être déterminés. |

Ne combinez pas `-Stage` et `-Phase`. Sans sélection, le lanceur exécute seulement le diagnostic initial. Une liste de phases est exécutée dans l’ordre du parcours défini, avec la partie administrateur avant la partie utilisateur.

Les numéros sont des chaînes de caractères : gardez les guillemets, notamment autour de `'00'`. Exemple dans un terminal administrateur :

```powershell
.\Invoke-Bootstrap.ps1 -Phase '10','20','50' -ConfigPath .\config.local.psd1 -Verbose
```

Pour contrôler le bloc utilisateur sans installer :

```powershell
.\Invoke-Bootstrap.ps1 -Stage User -CheckOnly -ConfigPath .\config.local.psd1
```

`CheckOnly` peut produire des `FAIL` si un prérequis est absent. Il poursuit les phases demandées pour montrer les écarts ; une exécution d’installation s’arrête à la première phase en échec. Les contrôles peuvent créer des logs et la recherche Windows Update peut rafraîchir ses métadonnées, même en `CheckOnly`.

## Windows Update, heure et redémarrages

### Windows Update

Par défaut, les résultats Windows Update sont en `INFO` : mises à jour en attente, erreur de recherche, délai dépassé ou redémarrage signalé par l’agent Windows Update. Ils ne bloquent pas le parcours. Une recherche qui échoue reste indiquée comme inconnue ; elle n’est pas présentée comme une machine à jour.

Le scan utilise la source Windows Update ou WSUS configurée sur le poste. Il ne demande pas le téléchargement ni l’installation de mises à jour. `WindowsUpdateTimeoutSeconds` limite sa durée, à 180 secondes par défaut.

Pour rendre ce contrôle obligatoire :

```powershell
.\Invoke-Bootstrap.ps1 -Phase '70' -ConfigPath .\config.local.psd1 -WindowsUpdateMandatory
```

Avec cette option, les mises à jour non facultatives en attente, le redémarrage Windows Update requis et les résultats inconnus donnent `FAIL`. Les mises à jour facultatives restent informatives. Le flag est transmis aux phases et conservé dans les commandes de continuation proposées.

### Synchronisation de l’heure (NTP)

Le bootstrap contrôle l’état du service de temps Windows puis mesure l’écart avec `NtpProbeHost`. La console affiche la synchronisation et une ligne compacte avec le serveur, l’écart maximal en millisecondes, le seuil configuré et le nombre d’échantillons.

Les sorties brutes `w32tm /query /status /verbose` et `stripchart` sont conservées dans les logs et les rapports JSON. Elles sont aussi visibles avec `-Verbose`.

Si le contrôle échoue, les instructions indiquent les commandes à lancer dans un terminal administrateur pour démarrer le service ou resynchroniser l’heure. Elles utilisent les sources Windows existantes ; le bootstrap ne remplace pas la configuration des pairs. Un serveur de diagnostic injoignable peut demander une correction réseau : une resynchronisation seule ne garantit pas de le rendre accessible.

### Redémarrage demandé

Le bootstrap peut s’arrêter après avoir activé une fonctionnalité ou installé un composant qui exige un redémarrage. Il indique alors quoi relancer après la reconnexion. Les codes de sortie utiles sont :

| Code | Signification |
|---|---|
| `0` | Les phases demandées ont réussi. |
| `1` | Une phase ou un contrôle a échoué ; lire les `FAIL` et corriger avant de reprendre. |
| `3010` | Un redémarrage Windows est nécessaire avant de poursuivre. |

Le bootstrap ne redémarre pas la machine automatiquement. Les marqueurs généraux de maintenance Windows, les opérations de fichiers en attente et les besoins de redémarrage des installateurs restent contrôlés, même lorsque Windows Update est informatif.

## Lire les résultats et retrouver les détails

| Statut | Couleur | Interprétation |
|---|---|---|
| `PASS` | Vert | Contrôle réussi ou action appliquée. |
| `FAIL` | Rouge | Échec à corriger avant la suite. |
| `INFO` | Turquoise | Information ou résultat non bloquant. |
| `PLAN` | Turquoise | Action qui serait appliquée hors `CheckOnly`. |
| `WARN` | Jaune | Point à examiner, sans blocage automatique. |
| `MANUAL` | Jaune | Action ou choix à réaliser manuellement. |
| `UNKNOWN` | Jaune | Statut de présentation disponible pour un résultat inconnu ; les contrôles appliquent leur propre règle de blocage. |

L’affichage normal est compact : une ligne par contrôle de binaire, un résumé par disque et la version WSL. Les instructions de login, de redémarrage et de reprise restent visibles. Une commande de continuation est proposée après réussite ; la validation finale affiche le message de fin.

Pour les chemins et les sorties techniques :

```powershell
.\Invoke-Bootstrap.ps1 -Stage Preflight -ConfigPath .\config.local.psd1 -Verbose
```

`-Verbose` est disponible sur le lanceur, les scripts de phase et l’assistant. Le lanceur le transmet aux phases et les commandes de continuation le conservent. Les sorties d’installation WinGet, npm, WSL et des extensions sont détaillées avec cette option. Les sondes internes silencieuses ne sont pas toutes rejouées en console ; leurs résultats restent dans les logs.

Les fichiers texte et rapports JSON sont placés dans `logs/`, avec une date et le nom de la phase. Ils conservent les détails indépendamment de l’affichage console. Les erreurs natives indiquent le code de sortie et le diagnostic, même sans `-Verbose`.

### Confidentialité des fichiers locaux

Les logs peuvent contenir le nom du compte Windows, son identifiant SID, des chemins locaux, l’identité Git et des informations réseau. Relisez-les et masquez ces données avant de les joindre à une issue publique. Les connexions aux CLI se font manuellement, en dehors de la journalisation du bootstrap ; aucune clé API n’est demandée dans le fichier de configuration.

Conservez vos paramètres dans `config.local.psd1`, ignoré par Git, et gardez `config.psd1` générique. Les logs, sauvegardes, fichiers `.env` et formats courants de clés privées sont également ignorés. Ces règles ne remplacent pas une relecture de `git diff --cached` avant chaque commit : Git peut suivre un fichier ignoré si on force son ajout.

## Organisation du dépôt

| Emplacement | Contenu |
|---|---|
| `Configure-Bootstrap.ps1` | Assistant de configuration et de confirmation du login. |
| `Invoke-Bootstrap.ps1` | Lanceur des groupes et des phases, gestion des arrêts et de la continuation. |
| `00-*.ps1` à `70-*.ps1` | Scripts de phase décrits ci-dessus. |
| `config.psd1` | Paramètres par défaut, suivis par Git. |
| `config.local.psd1` | Votre configuration personnelle, générée par l’assistant et ignorée par Git. |
| `lib/Common.ps1` | Journalisation, commandes externes, installation et contrôles communs. |
| `lib/Configuration.ps1` | Lecture des réponses, sauvegarde du PSD1 et génération des commandes. |
| `lib/Storage.ps1` | Identification des volumes et contrôle de l’espace libre. |
| `lib/WindowsUpdate.ps1` | Recherche Windows Update et application de la politique informative ou obligatoire. |
| `tests/` | Tests automatisés détaillés ci-dessous. |
| `logs/` | Résultats des exécutions, ignorés par Git. |
| [SOURCES.md](SOURCES.md) | Références officielles des outils et méthodes d’installation. |

Les scripts PowerShell sont enregistrés en UTF-8 avec BOM pour que Windows PowerShell 5.1 lise correctement les accents et chemins. Les modifications du code et de la documentation se suivent avec les commits Git. Les configurations personnelles, sauvegardes, fichiers temporaires de tests et logs ne doivent pas être commités.

## Testing

Les tests du répertoire `tests/` vérifient les scripts et leurs comportements sans installer les applications sur le poste. Ils sont écrits en PowerShell et ne nécessitent pas de module de tests externe. Les opérations sensibles sont remplacées par des fonctions simulées ou des scripts temporaires.

### Rôle de chaque fichier

| Fichier | Ce qu’il contrôle |
|---|---|
| [Test-Bootstrap.ps1](tests/Test-Bootstrap.ps1) | Syntaxe des scripts ; absence de modification en `CheckOnly` ; distinction entre erreur WinGet et package absent ; contrôles Node/LTS, alimentation, RAM et alias Python ; scénarios NTP et marqueurs de redémarrage. |
| [Test-Configuration.ps1](tests/Test-Configuration.ps1) | Sérialisation et lecture sûre des valeurs PSD1 ; types conservés ; chemins avec espaces/apostrophes et phases entre guillemets ; questionnaire simulé ; `PreviewOnly` ; sauvegarde avant remplacement ; conservation des paramètres reconnus et exclusion des clés inconnues. |
| [Test-Continuation.ps1](tests/Test-Continuation.ps1) | Commandes et contexte admin/utilisateur proposés après les phases ; confirmation du login avant validation ; fin du parcours ; absence de continuation après échec ou redémarrage ; transmission de `-Verbose` et `-WindowsUpdateMandatory` à des phases simulées. |
| [Test-Stages.ps1](tests/Test-Stages.ps1) | Composition et ordre des groupes `Preflight`, `Administrator`, `User` ; activation de `CheckOnly` dans le diagnostic initial ; sélection du fichier de configuration par défaut, priorité au fichier local et respect de `-ConfigPath`. Les phases sont remplacées par des scripts inertes exécutés dans des processus enfants. |
| [Test-NativeCommands.ps1](tests/Test-NativeCommands.ps1) | Capture des sorties standard et d’erreur ; refus d’une commande absente même après un succès ; refus d’un code de sortie non autorisé et acceptation des codes explicitement permis. Les processus enfants ne font aucune installation. |
| [Test-Storage.ps1](tests/Test-Storage.ps1) | Regroupement des usages par volume ; seuils d’espace libre ; manque d’espace sur C: ou D: ; volume absent ; point de montage ; refus d’un chemin relatif. Les volumes et leurs capacités sont simulés. |
| [Test-BackendLogin.ps1](tests/Test-BackendLogin.ps1) | Arrêt de la validation avant ses contrôles lorsque le login n’est pas confirmé ; instructions et fichier de configuration affichés ; poursuite lorsque la confirmation est présente. Aucun compte n’est connecté. |
| [Test-WindowsUpdate.ps1](tests/Test-WindowsUpdate.ps1) | Résultats sans mise à jour, mises à jour obligatoires/facultatives, redémarrage, recherche partielle et erreur/timeout ; mode informatif ou obligatoire ; traitement du marqueur registre Windows Update. Aucune recherche Windows Update réelle n’est lancée. |

### Exécuter un test

Depuis la racine du dépôt, dans un terminal utilisateur normal :

```powershell
pwsh -NoProfile -File .\tests\Test-Configuration.ps1
```

Pour exécuter le même test sous Windows PowerShell 5.1 :

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Configuration.ps1
```

Dans cette dernière commande, la politique d’exécution est définie uniquement pour le processus de test ; elle ne modifie pas la politique persistante du poste.

### Exécuter toutes les suites

Cette commande utilise le moteur du terminal courant et lance chaque fichier dans un processus séparé. Elle s’arrête si une suite échoue :

```powershell
$testEngine = (Get-Process -Id $PID).Path
Get-ChildItem -LiteralPath .\tests -Filter 'Test-*.ps1' |
    Sort-Object Name |
    ForEach-Object {
        & $testEngine -NoProfile -ExecutionPolicy RemoteSigned -File $_.FullName
        if ($LASTEXITCODE -ne 0) {
            throw "Échec de la suite : $($_.Name)"
        }
    }
```

Pour contrôler les deux environnements pris en charge, exécutez cette commande une fois dans PowerShell 7 et une fois dans Windows PowerShell 5.1.

### Interpréter les résultats

Chaque suite affiche ses assertions réussies et un résumé. Certains scénarios produisent volontairement des lignes `FAIL` pour vérifier la gestion d’une erreur. Une suite réussie se termine normalement ; un échec de test provoque une exception et un code de sortie non nul.

Les suites qui créent des fichiers utilisent des dossiers temporaires `tests/scratch-*` et les nettoient à la fin. Ces dossiers sont ignorés par Git. L’exécution peut faire apparaître des traces et aperçus de configuration simulés : ils ne correspondent pas à une modification de votre configuration personnelle.

Ces tests couvrent la logique du bootstrap et les parcours simulés. Ils ne remplacent pas l’installation réelle des packages, les redémarrages, le premier lancement de Docker ou une conversation avec un CLI connecté. La validation finale du poste sert à contrôler l’état de la machine après le parcours réel.

## Licence

Ce projet est distribué sous [licence MIT](licence.md), selon le [texte publié par l’Open Source Initiative](https://opensource.org/license/mit). Le code est fourni « AS IS », en l’état, sans garantie. La licence des logiciels installés reste celle de leurs éditeurs respectifs.
