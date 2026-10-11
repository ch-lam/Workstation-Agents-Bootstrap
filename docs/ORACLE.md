# Profil Oracle Developer

Le profil est optionnel. SQLcl et son JDK doivent être préparés pendant le bloc administrateur, avant la phase 20. Le bootstrap choisit une procédure manuelle reproductible pour la distribution Oracle : aucun téléchargement depuis une source tierce, aucune licence acceptée implicitement, aucun moteur Oracle Database installé.

## Préparation administrateur

1. Choisissez une version exacte depuis [Oracle SQLcl Downloads](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/download/). Consultez les exigences Java de cette version dans la [documentation Oracle](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/index.html). Ne déduisez pas la version Java requise de celle de SQL Developer, qui est un autre produit.
2. Téléchargez l’archive depuis le lien officiel Oracle, examinez la licence et conservez son URL exacte, son nom, sa version et son SHA256 dans votre procédure de déploiement. Vérifiez le hash contre une référence éditeur ou un artefact préalablement approuvé ; calculer le hash seul ne prouve pas la provenance.
3. Installez un JDK compatible pour tous les utilisateurs sous Program Files depuis une distribution officielle approuvée. Conservez également sa version, sa provenance et son intégrité. Ne remplacez pas silencieusement un JAVA_HOME utilisé par d’autres applications.
4. Extrayez l’archive SQLcl dans un dossier versionné sous Program Files. Conservez les ACL héritées : Administrators/SYSTEM en écriture, utilisateurs en lecture/exécution seulement. N’activez pas un mode portable enregistrant les préférences dans ce dossier partagé.

Exemple de préparation, à adapter aux chemins et au hash approuvés (ne pas copier les marqueurs littéralement) :

```powershell
$archive = 'D:\Packages\sqlcl-VERSION.zip'
$expectedHash = 'SHA256_APPROUVE_DE_64_CARACTERES'
if ($expectedHash -notmatch '^[a-fA-F0-9]{64}$') { throw 'Renseigner le SHA256 approuve' }
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'Archive SQLcl non conforme'
}
$destination = Join-Path $env:ProgramFiles 'Oracle\SQLcl-VERSION'
if (Test-Path -LiteralPath $destination) { throw 'Destination existante : inspecter avant modification' }
Expand-Archive -LiteralPath $archive -DestinationPath $destination
# Localisez bin\sql.exe ou bin\sql.bat dans l'arborescence extraite.
# SqlclHome est son dossier parent (souvent ...\sqlcl), pas ...\bin.
```

Renseignez ensuite votre configuration locale :

```powershell
OracleDeveloper = @{
    Enabled = $true
    SqlclHome = 'C:\Program Files\Oracle\SQLcl-VERSION\sqlcl'
    JavaHome = 'C:\Program Files\Java\JDK-VERSION'
    VSCodeExtension = 'Oracle.oracledevtools'
}
```

Les noms de dossiers sont des exemples, pas des valeurs codées dans le bootstrap. Il utilise le Program Files de la machine, exige que les binaires soient sous cette racine et vérifie leur présence avant exécution.

La phase 20 lance Java et SQLcl avec leur option de version, prépare le PATH machine vers SQLcl et JAVA_HOME s’il est absent. Si un JAVA_HOME machine différent existe, elle s’arrête pour résolution explicite. Aucune connexion à une base n’est tentée. Un couple Java/SQLcl incompatible doit faire échouer cette phase, avant de changer de compte.

## Utilisateur standard

La nouvelle session hérite du PATH et de JAVA_HOME machine. Les phases 30 et 70 vérifient aussi l’environnement effectif et détectent un SQLcl masqué ou un JAVA_HOME personnel contradictoire. La phase 60 installe Oracle Developer Tools for VS Code dans le profil de cet utilisateur. L’extension est [Oracle.oracledevtools](https://marketplace.visualstudio.com/items?itemName=Oracle.oracledevtools) ; elle n’est pas remplacée automatiquement par Oracle SQL Developer for VS Code.

Les mots de passe, wallets, fichiers de connexion et historiques restent personnels. Configurez TNS_ADMIN uniquement si nécessaire, vers un emplacement personnel approprié. Ne configurez pas un wallet partagé sous Program Files. Testez une connexion réelle hors des journaux du bootstrap, avec un compte de base autorisé et sans mot de passe dans la ligne de commande.

## Mise à jour et acceptation

Préparez la nouvelle version dans un autre dossier protégé, vérifiez son intégrité et sa compatibilité Java, puis changez explicitement les chemins configurés et le JAVA_HOME si nécessaire. Le bootstrap ne supprime pas les anciennes distributions ni les environnements Java.

Acceptation : le compte standard lance le SQLcl configuré depuis un nouveau terminal, l’extension Oracle est installée dans son profil, il ne peut pas modifier les binaires système, et aucun identifiant ne figure dans Git, le PSD1 ou les journaux.
