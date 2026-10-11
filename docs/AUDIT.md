# Audit et adaptation multicomptes

Base auditée : `ba9b693a5350822c387858684fcf9db1e02e7f7b`. Audit du 11 octobre 2026. Aucun bootstrap ni installateur exécuté sur la station pendant ce travail.

## Écarts et traitement

| Priorité | Constat initial | Modification |
|---|---|---|
| P0 | WinGet acceptait toute installation visible, indépendamment du périmètre | Get-WinGetState/Ensure-WinGet sélectionnent le scope, bloquent les conflits et n'effectuent aucun repli utilisateur |
| P0 | Python était explicitement utilisateur, uv sans scope | Catalogue machine partagé, Python/uv déplacés en phase 20 |
| P0 | Logs et rapport de succès dans le dépôt | Dossiers personnels par compte et type de phase sous LOCALAPPDATA |
| P0 | Confirmation de login partagée par un booléen | État personnel associé au SID ; ancien booléen insuffisant |
| P0 | docker info contrôlait le contexte actif | Validation explicite du named pipe local et de chaque contexte SSH |
| P1 | Docker était uniquement un booléen | Quatre modes, normalisation des anciens fichiers et rejet des contradictions |
| P1 | HypervisorPresent était considéré comme preuve suffisante | Avertissement si preuve CPU/SLAT manquante ; qualification réelle WSL2/Proxmox documentée |
| P1 | Préfixe npm non vérifié, PATH seulement temporaire | Préfixe personnel, contrôle d'écriture hors CheckOnly, PATH utilisateur persistant idempotent |
| P1 | Sorties natives intégrales dans les logs | Sorties brutes omises, codes conservés, filtrage des détails structurés |
| P1 | Reprise et documentation imposaient le même compte | Maintien des blocs 10/20/50 puis 30/40/60/70 ; un seul changement nominal |
| P1 | Oracle et OpenRouter absents | Profil Oracle avec procédure officielle reproductible, validation Java/SQLcl et extension ; instructions fournisseur OpenRouter |
| P2 | Tests incomplets pour les nouveaux scénarios | Tests isolés de migration, scopes, SID, Docker, npm/Oracle et CI Windows 5.1/7 |

## Architecture préservée

Les phases numérotées et les stages restent inchangés. La configuration demeure un PSD1 importé comme données. Les bibliothèques ajoutées sont Settings (normalisation/SID), Provisioning (PATH/catalogue/scopes auxiliaires), Docker (contextes/validation) et Oracle (prérequis/chemins). Le catalogue Packages.psd1 centralise les applications machine et leurs commandes attendues.

L'administrateur termine les installations système, les prérequis Docker/SSH et la préparation Oracle avant de changer de compte. Windows Terminal constitue une exception documentée : distribution MSIX sans élévation sous le compte standard. Le premier lancement de Desktop, les extensions, SSH, Git, npm et toutes les connexions restent personnels.

Les numéros et l'ordre 00,10,20,50,30,40,60,70 sont conservés. Le code 3010 provoque une reprise dans le contexte correspondant ; les paquets déjà conformes ne sont pas mis à jour implicitement. Les modes Docker n'enlèvent pas les installations ni les contextes existants.

## Profil cible

Utiliser `examples/config.both.psd1`, sans nom de poste ou de compte codé en dur. Ajouter uniquement les endpoints SSH effectivement fournis. Oracle est optionnel et reste désactivé dans l'exemple tant que les chemins officiels ne sont pas préparés ; activer ensuite OracleDeveloper.Enabled et renseigner SqlclHome/JavaHome. Timon reste hors bootstrap.

## Validation et limites

Les tests exécutent uniquement des commandes simulées, fixtures inertes et fichiers temporaires isolés. Les résultats sont livrés séparément avec la version adaptée. Aucune validation réelle de Docker, SQLcl, WinGet ou de la VM cible n'est revendiquée. Les critères de qualification et les risques figurent dans ACCEPTANCE.md ; la procédure Oracle figure dans ORACLE.md.

Les installations personnalisées dans d'autres profils, les ACL modifiées et les versions futures des paquets doivent être vérifiées dans une VM de qualification. Le code ne configure ni droits Docker globaux, ni clés SSH, ni ports TCP, ni réseau/VPN/RDP ; il préserve les protections Windows. L'accès à un daemon Docker reste un privilège important et un compte standard n'est pas une sandbox complète.
