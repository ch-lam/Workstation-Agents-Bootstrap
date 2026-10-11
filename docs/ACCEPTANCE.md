# Qualification avant déploiement

Les tests automatisés sont des tests isolés. Ils ne certifient ni les installateurs actuels du catalogue WinGet, ni Docker Desktop sous Proxmox, ni les ACL d’une machine réelle.

Utiliser une VM Windows 11 Pro x64 de qualification avec deux comptes distincts, administrateur et utilisateur standard. Prendre un snapshot avant les installations. Le parcours nominal exige un seul changement de compte : 00 facultatif puis 10/20/50 sous l’administrateur, redémarrages inclus ; ensuite 30/40/60, logins et 70 sous l’utilisateur.

| Scénario | Résultat requis |
|---|---|
| Nouvelle installation | Les outils communs sont installés machine ; aucune dépendance au profil administrateur |
| Deuxième exécution | Aucun doublon d’installation, PATH ou contexte ; aucune mise à jour implicite |
| Mauvais périmètre existant | Erreur explicite avant création d’un doublon ; aucune désinstallation |
| UAC avec autre identité | Aucune configuration personnelle destinée au compte standard écrite dans le profil administrateur |
| Nouveau terminal standard | PowerShell, Git, Node/npm, Python, uv/uvx, VS Code, gh et glab fonctionnent ; Sysinternals est accessible sans lancer une fonction privilégiée |
| Permissions uv machine | La phase 20 corrige automatiquement le seul paquet uv avec Users RX, sans ajout de droits d'écriture ; une reprise ne modifie pas les ACL déjà conformes |
| Cibles portables inattendues | Racine personnalisée, jonction dans le paquet ou cible uv/uvx hors du paquet : erreur avant correction récursive ; aucune permission élargie ailleurs |
| Reboot 3010 | Reprise avec mêmes paramètres ; rester dans le bloc administrateur tant qu’il n’est pas terminé |
| None | Aucune installation Docker/SSH/WSL demandée par Docker ; existants non supprimés |
| RemoteCLI | Aucun WSL ou Desktop installé ; seul le client machine et SSH sont préparés |
| Both | Une seule origine de docker.exe ; contexte local et chaque distant validés indépendamment |
| Contexte distant actif | Le moteur local arrêté provoque un FAIL local, même si le distant répond |
| Contexte en conflit | Endpoint existant préservé ; aucune sélection, suppression ou réécriture automatique |
| SSH | Hôte connu et authentification préparée manuellement ; aucune clé générée ou connexion TCP 2375 |
| Distant hors ligne | Required=true échoue ; false avertit ; sonde bornée à 30 s, sans basculement local |
| Volumes distants | Les chemins désignent le disque du serveur ; documenter transfert/synchronisation séparément |
| Oracle activé | Binaires/JDK préparés avant fin du bloc admin ; SQLcl et extension fonctionnent sous le compte standard |
| Confirmation login | Une confirmation d’un autre SID ou l’ancien booléen partagé ne valide pas le compte cible |
| Logs | Dossiers personnels, aucun token ni sortie native brute ; dépôt conservé sans écriture utilisateur |
| CheckOnly | Aucun installateur, contexte, PATH, ACL, service ou fonctionnalité modifié ; logs et diagnostics autorisés |
| Protections | Defender, SmartScreen, UAC, pare-feu, réseau, VPN et RDP inchangés |

## Risques et limites

- WinGet et MSIX sont aussi sensibles à l’enregistrement par utilisateur, aux stratégies d’entreprise et aux versions du catalogue. L’absence de périmètre compatible doit échouer sans repli silencieux. Valider les paquets actuels dans la VM.
- Les installations existantes dans d’autres profils ne sont pas toutes visibles depuis un seul inventaire. Ne pas certifier l’absence universelle de doublons sur la seule base de WinGet.
- Proxmox/KVM : faire vérifier nested virtualization et CPU/SLAT sur l’hôte. HypervisorPresent seul ne prouve rien. Vérifier réellement le moteur Desktop/WSL2 ; ne pas annoncer un support officiel Docker inexistant.
- Docker-users et les sockets des moteurs distants constituent des accès privilégiés. Aucune appartenance de groupe n’est ajoutée par le bootstrap.
- Une liste distante vide certifie uniquement le client, pas un serveur. Une confirmation de login est déclarative, pas une vérification de validité des tokens.
- Les filtres de logs sont une défense complémentaire ; ils ne peuvent identifier un secret arbitraire mis dans un champ libre. Ne fournir aucun secret aux scripts, et réaliser les logins hors bootstrap.
- Le PATH système et l’origine des binaires sont contrôlés ; les ACL personnalisées, jonctions et logiciels tiers nécessitent une revue en qualification. Ne pas exécuter une copie modifiable par un compte standard avec élévation.
- Un compte standard n’est pas une sandbox complète ; conserver les protections des agents.
- OpenRouter est documenté, sans test réseau facturable ni configuration automatique de Timon.
