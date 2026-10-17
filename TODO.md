# TODO BerserkMC — Problèmes relevés par scan

Scan complet du repo (branche `offline-mode`, commit `a7fdd6dd` + WIP non commité).
Légende : P0 = bug bloquant, P1 = doit être corrigé, P2 = à compléter, P3 = dette/cosmétique.

---

## P0 — Bugs / valeurs factices en production

- [x] **Path launcher codée en dur dans les Settings** — `launcher/qml/views/SettingsView.qml` affiche `C:\Users\Karim\Documents\BerserkLauncher` au lieu de `APPLICATION->root()`. UI fausse pour tout autre utilisateur / machine. — Corrigé : nouveau `Q_INVOKABLE QmlBridge::launcherRoot()` + texte lié.
- [x] **UUID offline factice** — `AccountsView.qml` affichait toujours `b9c8d1c1-2f3a-3b1c-9e2d-58e1f5c2a4b6`. — Corrigé : `QmlBridge::rebuildAccounts` expose `offlineUuid` (via `profileId()`), l'UI l'affiche.
- [x] **"Voir le changelog" ouvrira un fichier inexistant** — `QmlBridge::openChangelog` cherchait uniquement dans `APPLICATION->root()/changelog.md`. — Corrigé : recherche dossier d'install puis data, sinon toast d'erreur clair.
- [x] **Drag de la Titlebar cassé (fuite de coordonnées)** — `Titlebar.qml` : `mouseX` relatif au MouseArea qui bouge → jitter. — Corrigé : `window.startSystemMove()` (Qt 5.15) déclenché après seuil de 4 px.
- [x] **Recherche bibliothèque inopérante** — `LibraryView.qml` : le `TextField` `search` n'était lié à aucun filtre. — Corrigé : `applyInstancesFilter()` sur `onTextChanged`, message "aucun résultat".
- [x] **Toggle "Animations" (Settings) non fonctionnel et non persisté** — Corrigé : persisté (`Animations`), `Theme.durFast/durMd/durSlow` rendus mutables et mis à 0 quand désactivé.
- [x] **Toggle "Détecter Java" non persisté** — Corrigé : chargé/persisté via `App.getSetting("DetectJava")`.
- [x] **`QmlIconProvider` thread-unsafe** — Corrigé : rendu direct en `QImage` via `QPainter` (plus de `QPixmap` hors thread GUI).
- [x] **Toast de fin de lancement trompeur** — Corrigé : affiche le **nom** de l'instance et "lancé" au lieu de l'id + "terminé".
- [x] **Itinéraire du drag de la Titlebar** — même MouseArea (drag + double-clic) exécutait aussi la logique de drag sur double-clic. — Corrigé : drag seulement après seuil de mouvement (le double-clic reste intact).

---

## P1 — Rebranding incomplet (MultiMC → BerserkMC)

### Naming global incohérent (BerserkMC vs BerserkLauncher vs MultiMC)
- [x] Nom unifié sur **BerserkMC** : `README.fork.md` réécrit (`:1,16,48,74` → BerserkMC, `berserklauncher.cfg` → `berserkmc.cfg`, section build Windows corrigée MSYS2/Qt5.15, section push → `gagga1/BerserkMC`). `CMakeLists.txt:144` = BerserkMC. Build OK.
- [x] `deploy.sh:5,11` + `dev-qml.sh:16` : paths alignés (`BUILD_DIR=/c/opencode/project/BerserkMC/build-mingw64`, `INSTALL_DIR=.../BerserkMC`). Build OK.

### Ressources Qt / icônes
- [x] Renommé `launcher/resources/multimc/` → `resources/berserkmc/` (git mv) + `multimc.qrc` → `berserkmc.qrc` ; MAJ `launcher/CMakeLists.txt:887`, `launcher/ui/dialogs/UpdateDialog.ui:88`, `launcher/main.cpp:43` (`Q_INIT_RESOURCE(berserkmc)`). Build OK.
- [x] Préfixe ressource `/icons/multimc` → `/icons/berserkmc` (`berserkmc.qrc:3`) + tous les usages : `Application.cpp:854-857`, `InstanceCard.qml:12`, `InstanceSidebar.qml:12,69`, `LibraryView.qml:306`. Build OK.
- [x] Thème d'icônes : `resources/berserkmc/index.theme:2` (`Name=berserkmc`) + `Inherits=berserkmc` dans `resources/{flat,iOS,OSX,pe_blue,pe_colored,pe_dark,pe_light}/index.theme` ; défaut `IconTheme "berserkmc"` dans `LauncherPage.cpp:223`. Build OK.
- [x] Renommé `launcher/resources/{flat,iOS}/scalable/multimc.svg` → `berserkmc.svg` (assets non référencés par les `.qrc`, renommage purement cosmétique). Note : libellés du combo thème = "Default"/"Simple (...)" → aucun branding à corriger.

### Branding Windows/macOS
- [x] `CMakeLists.txt:152` → `branding/BerserkMC.icns` (renommé) ; `:153` → `branding/berserkmc.rc` (renommé) ; `:200` → `MACOSX_BUNDLE_GUI_IDENTIFIER "org.berserkmc.*"`. Build OK.
- [x] `branding/multimc.rc:7` référence désormais `BerserkMC.manifest` (renommé) ; `BerserkMC.manifest:3` → `assemblyIdentity name="BerserkMC.Application.5"`. `MultiMC.ico` orphelin supprimé (`BerserkMC.ico` déjà utilisé par le rc). Build OK.
- [x] `branding/genicons.sh:10,21` génère désormais `BerserkMC.ico`/`BerserkMC.icns`.

### Java package / Maven / IDs (`org.multimc.*`)
- [x] **Décision (utilisateur) : renommer le package Java uniquement.** Package `org.multimc` → `org.berserkmc` (dir `libraries/launcher/org/berserkmc/`, `package`/`import`/qualifieurs, `CMakeLists.txt:6,10-17` entry point + SRC, `LauncherPartLaunch.cpp:110`). Sûr : `NewLaunch.jar` est buildé par notre CMake (`add_jar`), donc les deux côtés utilisent notre classe. **Conservé** : propriétés `multimc.instance.title/icon` (contrat externe du mod **CraftPresence**, cf. commentaire `OneSixLauncher.java:80`) — documenté.
- [x] **Coordonnées Maven/IDs de composants upstream conservées** (`org.multimc.jarmod.*`, `org.multimc.jarmods:*`, `org.multimc.atlauncher:*`, `org.multimc:customjar:1`, `org.multimc.custom.*`) — décision utilisateur. Ids opaques stockés par-instance → les renommer ne casserait pas les instances existantes, mais on limite le risque sur l'import/format de packs.

### URLs runtime (services upstream)
- [x] NEWS/RSS (`multimc.org`) + `META_URL` (`meta.multimc.org`) **conservés** (endpoints fonctionnels — décision utilisateur). `BUG_TRACKER_URL` → `https://github.com/gagga1/BerserkMC/issues`. Build OK.
- [x] `BuildConfig.h:108,109,119` **conservés** (`files.multimc.org/fmllibs`, `/translations`, `TECHNIC_API_BUILD="multimc"`) — fonctionnels. Build OK.
- [x] Références GitHub → fork : `UpdateDialog.cpp:37,51,92` (`api.github.com/repos/gagga1/BerserkMC/compare/…offline-mode` + `github.com/gagga1/BerserkMC/issues`), `LanguageSelectionWidget.cpp:51` (`…/wiki/Translating-BerserkMC`), `PageContainer.cpp:210` (`…/wiki/`). Conservés fonctionnels : `TranslationsModel.cpp:577`, `AboutDialog.cpp:137` (patrons.txt). Build OK.
- [x] Clés API upstream **conservées** (PasteEE / MSA client id / Imgur) — décision utilisateur.
- [x] Sentinel PasteEE `"multimc"` **conservé** (identifiant interne invisible à l'utilisateur ; le libellé affiché est déjà « BerserkMC key » ; évite de casser les cfg existants).

### Docs & packaging
- [x] `.github/ISSUE_TEMPLATE/*` : rebrandés (Discord `discord.gg/berserk`, wiki/issues → `gagga1/BerserkMC`, "MultiMC"→"BerserkMC"). 3 fichiers réels (bug_report, config, suggestion), pas 5.
- [x] `launcher/package/rpm/MultiMC5.spec` → `BerserkMC.spec` + contenu rebrandé (Name/URL/Provides/paths `/opt/berserkmc`) ; `launcher/package/ubuntu/multimc/` → `berserkmc/` (desktop, metainfo, man, control, opt/berserkmc) rebrandé. NOTE : le wrapper télécharge toujours le binaire upstream MultiMC (pas d'artifact Linux BerserkMC) — documenté dans run.sh + READMEs.
- [x] `doc/multimc.1.txt` → `doc/berserkmc.1.txt` (nom, titre, URLs → fork). Idem man `berserkmc.1`.
- [x] `README.md` réécrit (page d'accueil BerserkMC : offline-only, build, licence, politique fork) ; `README.fork.md` rebrandé ; `BUILD.md` (clone URLs → fork, Qt 5.15, note MSYS2, chemins `~/BerserkMC`). `COPYING.md:1` → titre BerserkMC. `changelog.md` **conservé tel quel** = historique upstream légitime (ne pas falsifier).
- [x] `cmake/MacOSXBundleInfo.plist.in:40` : texte de permission macOS → "BerserkMC does not need access…".
- [x] `cmake/UnitTest/test.rc:17` : `CompanyName "BerserkMC Contributors"`.
- [x] `launcher/updater/testdata/tst_DownloadTask-test_writeInstallScript.xml:9` : `MultiMC.exe` → `BerserkMC.exe` (+ dest). Fixture **orpheline** (aucun test `writeInstallScript` ne la référence) → modification cosmétique sans impact.

### Trailing logic/strings
- [x] Commentaires `JavaUtils.cpp:80,87,405` → "BerserkMC". `InstanceImportTask.cpp:110-113` **conservés** : il s'agit du *format* de pack MultiMC (`ModpackType::MultiMC`, `instance.cfg`), pas du branding (comme "Technic"). (`NotificationChecker.cpp:42` déjà corrigé en P1-d.)

---

## P2 — Fonctionnalités incomplètes / UI QML morte

- [x] **NewInstance : 3 onglets sur 4 sont des stubs** — `NewInstanceView.qml:2-5,255,585` : Modrinth / CurseForge / Importer = texte "Bientôt — Phase 7". → onglets désactivés (dim + curseur interdit + tooltip « Bientôt disponible »), libellés reformulés « pas encore disponible dans BerserkMC ».
- [x] **Installation du mod-loader incomplète** — `QmlBridge.cpp:401-520` : contradiction `Q_UNUSED(loader)` vs code qui installe ; instance ré-resolue **par nom** (collision si 2 instances même nom) ; `setComponentVersion` ne déclenche pas le téléchargement des libs ; `setIcon("default")` codé en dur ; `createVanillaInstance` retourne `false` quand même. → `Q_UNUSED` retiré ; instance retrouvée **par id** (diff avant/après) ; version du loader filtrée par `ParentVersionRole` sur la version MC ; `resolve(Net::Mode::Online)` + attente de la tâche pour télécharger les libs ; retour `true` sur succès. `setIcon("default")` conservé (clé d'icône valide par défaut).
- [x] **Source de vérité des versions dupliquée** — `NewInstanceView.qml:90-127` fetch `launchermeta.mojang.com` via XHR alors que le bridge résout via `metadataIndex()` cpp. Une version choisie peut ne pas se résoudre à la création ; pas de mode offline. → le XHR est supprimé ; la liste vient de `QmlBridge::minecraftVersions()` (index meta cpp, cache local, `versionListChanged()`), même source que la création. `humanizeAge()` prend désormais des ms.
- [x] **Bouton "Créer l'instance" jamais désactivé** — `NewInstanceView.qml:568-573` : peut tirer avec `selectedVersion` par défaut `"1.21"` avant chargement / nom vide. → `selectedVersion`/`instanceName` démarrent vides ; bouton `enabled: page.canCreate` (nom non vide + version résolue + manifest chargé) ; `IconButton` affiche un état désactivé (opacité).
- [x] **Plusieurs champs bridge jamais consommés par l'UI** — `QmlBridge.cpp:192-194` (`stateText`, `ownsMinecraft`, `hasProfile`) ; `isRunning()` jamais appelé ; branches `openFolder` "central-mods"/"instances-root" jamais utilisées. → champs de compte morts, `isRunning()` et les deux branches `openFolder` supprimés ; commentaire d'en-tête aligné sur les kinds réellement gérés.
- [x] **PageHeader.rightContent** — slot déclaré mais aucune vue ne l'utilise (`PageHeader.qml:17,92`). → alias `rightContent` et la `Row` `rightSlot` supprimés ; aucune des 3 vues ne fournissait d'enfant.
- [ ] **Fonctions manquantes vs mockups** — `_mockups/B_main.html` : statusbar (Java + "à jour") absente ; logo dans la titlebar absent ; `E_settings.html` : sélecteur Thème absent, bouton refresh/detect Java à côté du champ JDK absent ; `D_add_instance.html` : champ recherche de version absent, tuile Add en pointillés absente (`InstanceCard.qml:37-45`).
- [ ] **"Dossiers" n'ouvre que le root** — `LibraryView.qml:96-129` malgré le pluriel ; pas de menu de dossiers.

---

## P3 — Build / packaging

- [ ] **Aucune CI** — `.github/` contient seulement des templates d'issues, aucun workflow GitHub Actions.
- [x] **Sources dupliquées dans la liste UI** — `launcher/CMakeLists.txt:877-882` : `CustomCommands.ui`, `InstanceCardWidget.ui`, `MCModInfoFrame.ui` listés deux fois chacun. → doublons retirés.
- [x] **Fichiers/hardcodes de build** — `CMakeLists.txt` référence `branding/multimc.rc`, `MultiMC.icns` (noms upstream) ; `TECHNIC_API_BUILD` ; version launcher figée `0.7.0` (vs texte UI "0.1.0"). → branding renommé (`berserkmc.rc`/`BerserkMC.icns`), version UI liée à `BuildConfig` (`QmlBridge::launcherVersion()`), métadonnées Windows alignées sur 0.7.0 ; `TECHNIC_API_BUILD="multimc"` conservé volontairement (endpoint fonctionnel).
- [x] **Instructions de build obsolètes** — `BUILD.md` & `README.fork.md` : Qt 5.6, OpenSSL 1.0.2g, chemins `MultiMC-Offline`/`BerserkLauncher`. Le build réel cible Qt 5.15+ / QML. → docs mises à jour (P1-e).
- [x] **Sous-modules** — `.gitmodules:1` nom `[submodule "depends/libnbtplusplus"]` mais path `libraries/libnbtplusplus` (incohérence de section). Vérifier `git submodule sync`. → nom aligné sur le path, gitdir déplacé, `git submodule sync` OK.
- [x] **Dépendance QML `QtGraphicalEffects`** non garantie au déploiement — `WelcomeView.qml:8`, `Icon.qml:6` (`ColorOverlay`). Si le module manque, toute l'UI échoue. (`Application.cpp:1489-1490` ne fait que logger.) → `deploy.sh` exige désormais chaque module QML (`QtQml QtQuick QtQuick.2 QtGraphicalEffects`) et échoue bruyamment s'il en manque un.
- [x] **`qmldir` mort** — `launcher/qml/qmldir` déclare `module BerserkMC.Ui` + singleton mais le path `qrc:/qml` n'est jamais importé ; `Theme` est enregistré manuellement (`Application.cpp:1479-1480`). → fichier supprimé (aucun `addImportPath("qrc:/qml")`, `Theme` enregistré en C++).
- [x] **Ressources inutilisées** — `qml/icons/chevron-down.svg` enregistré dans `qml.qrc:40` mais jamais référencé. → supprimé du `.qrc` et du disque.

---

## P4 — Dette technique / TODO/FIXME notables / cosmétique

- [ ] **TODO/FIXME marqués dans le code** (~200 occurrences). Les plus structurants :
  - `minecraft/ComponentUpdateTask.cpp:498-619` : résolution de dépendances à jeter → utiliser un graphe ; versions hardcodées (`HACK HACK HACK HACK FIXME`).
  - `meta/VersionList.cpp:79,99,163,174` : `FIXME: this is dumb`, dep "hard equals", reset du modèle.
  - `net/NetAction.h:32,108` : `@NUKE` / `FIXME: nuke`.
  - `Json.cpp:238` : n'échappe pas les caractères invalides.
  - `InstanceList.cpp:792` : pas d'abort pendant les retries de commit.
  - `BaseInstance.cpp:271-321` : write de fichier à chaque set, code mal placé.
  - `Application.cpp:135` : note Qt 5.15.2 instable sous Windows.
  - `QuickPlayTarget.cpp:20` : aucune validation possible.
- [x] **Valeurs codées en dur dans l'UI** — Fait : `Main.qml` toast dev "Bienvenue…" supprimé, `Toolbar.qml:11` (`"Karim_"`/`"K"` → défauts neutres), `NewInstanceView.qml` (`"1.21"`/`"1.21 Vanilla"` → vides), `SettingsView.qml:589` ("BerserkMC 0.1.0" → version liée). → `Main.qml` `currentSection` par défaut vide (plus de "QML PREVIEW") ; pastille ko-fi de `Titlebar.qml` supprimée (propriété `kofiUrl`, commentaire d'en-tête et couleurs `Theme.kofi*` mortes retirés).
- [ ] **Couleurs hardcodées hors thème** — `Titlebar.qml:66,74,125,134`, `AccountsView.qml`/`Toolbar.qml` (`#7ab1ff`), `NewInstanceView.qml` (`#ffa9a9`).
- [x] **Commentaires stalés** — `LibraryView.qml:2-3` ("Phase 3 mock data" alors que le modèle est réel) → commentaire d'en-tête corrigé (liste réelle via `App.instances`). `QmlBridge.cpp:403` : déjà résolu par le rework P2-68 (plus aucun commentaire contredisant le code).
- [ ] **`InstanceSidebar.qml:262,272`** : `contentY` mort ; **`InstanceCard.qml:44`** : tuile Add.
- [x] **`qsTr()` sur chaîne dynamique** — `AccountsView.qml` : `qsTr()` englobait une chaîne déjà passée à `.arg()` (extraction impossible). → `qsTr("COMPTE %1").arg(...)`.
- [x] **SEO/docs** : `SettingsView.qml:308` — texte exact du chemin Java corrigé (Adoptium Temurin sous `APPLICATION->root()/java/temurin-<version>` ; affiche dynamiquement le dossier de données via `page.launcherRoot`). `SettingsView.qml:286` (ancienne ligne) obsolète → MAJ.

---

## P5 — Java auto-install au lancement (option B)

Objectif : plus besoin d'aller dans les réglages de l'instance choisir Java à la main quand la version MC sélectionnée réclame un Java plus récent que celui configuré.

- [x] **Step `AutoInstallJava`** — `minecraft/launch/AutoInstallJava.{h,cpp}` inséré **après** l'étape `Update` et **avant** `CheckJava` (`MinecraftInstance.cpp:createLaunchTask`). Détermine la version Java minimale via les seuils `g_VersionFilterData` (mêmes règles que `VerifyJavaInstall`), teste le Java configuré via `JavaChecker`, et si absent/trop vieux télécharge **Adoptium Temurin** (via `JavaInstaller`) puis active le runtime **pour l'instance** (`JavaPath` + `OverrideJavaLocation=true`). Java 16 (MC 1.17) mappé sur Temurin 17 (16 non publié par Adoptium). Progression loggée dans la console de lancement.
  - Note (correctif) : placé à l'origine **avant** `Update`, le composant `net.minecraft` n'était pas encore résolu → `getComponent()` renvoyait `null` → succès silencieux aussitôt, puis `CheckJava` utilisait l'ancien Java et `VerifyJavaInstall` échouait (« Java 21 required »). Déplacé après `Update` (profil résolu) et `CheckJava` déplacé juste après lui pour valider le chemin éventuellement modifié. Vérifié : télécharge/active Java 21 puis lancement OK.
- [ ] **Feedback du download dans l'UI QML** — aujourd'hui la progression n'apparaît que dans la console widget (visible si `ShowConsole`). Prévoir un toast/bandeau QML pendant le téléchargement (nouveau signal `Application` → `QmlBridge`).
- [ ] **Choisir le Java *recommandé*, pas seulement `>=` requise** — actuellement si le Java configuré satisfait `VerifyJavaInstall` (`>=` minimum) il est utilisé tel quel ; un Java beaucoup plus récent peut casser des versions anciennes. Prévoir l'alignement sur la version majeure exacte.
- [ ] **Annulation du download** — `AutoInstallJava::canAbort()` renvoie `false` ; `JavaInstaller` n'a pas de méthode `cancel()`. Ajouter une annulation propre.

---

## P6 — Correctifs de compatibilité jeu

- [x] **"Multiplayer is disabled" sur MC 1.16.4/1.16.5 (compte offline)** — l'AuthLib embarquée dans ces versions ne contrôle pas le code HTTP des serveurs d'auth Mojang ; après le changement côté Mojang, une session non-authentifiée reçoit un JSON « valide » mal interprété → boutons Multiplayer/Realms grisés (« Multiplayer is disabled. Please check your Microsoft account settings. »), solo non touché. → nouveau `MinecraftInstance::processAuthArgs()` : en session `AuthSession::PlayableOffline` **et** version MC `1.16.4`/`1.16.5`, ajoute `-Dminecraft.api.env=custom` + les quatre hosts (`auth`/`account`/`session`/`services`) pointés vers `https://invalid.invalid`, ce qui transforme l'appel en échec réseau que l'ancien AuthLib gère correctement. `LauncherPartLaunch::executeTask` injecte ces args **avant** `javaArguments()` → les JVM args custom de l'instance restent surchargeables. Porté depuis PollyMC (commit `639a782`, « Fix offline multiplayer in 1.16.4-1.16.5 »). Vérifié : build MSYS2 OK, chaînes présentes dans `BerserkMC.exe`. Aucun effet sur les autres versions (le bug n'existe pas sur 1.17+) ni sur les serveurs `online-mode=true` (contrôle côté serveur). Réf. : `FabricMC/fabric-loom#915` (commentaire 1609154390).

---

## Notes

- Les headers de copyright `/* Copyright ... MultiMC Contributors */` (234 occurrences) sont **requis** par la licence Apache-2.0 → ne pas toucher.
- Le format d'instance `mmc-pack.json` (compat MultiMC) et l'enum `ModpackType::MultiMC` doivent être **conservés** pour la compatibilité.
- Dépendances ordonnées du rebrand : renommer la ressource multimc.qrc en premier (couple `CMakeLists`, `UpdateDialog.ui`, `main.cpp`, préfixes) puis le thème d'icônes, puis le branding, puis les URLs.