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
- [ ] Unifier le nom : `CMakeLists.txt:142` = **BerserkMC**, mais `README.fork.md` partout = **BerserkLauncher** (`:1,16,48,74`) et mentionne `berserklauncher.cfg` (faux, le fichier est `berserkmc.cfg`).
- [ ] `deploy.sh:11` et `dev-qml.sh:16` : paths de build stalés (`MultiMC-Offline-build`), `deploy.sh:5,11` : dossier `BerserkLauncher` → aligner sur BerserkMC.

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
- [ ] Classe principale `org.multimc.EntryPoint` (`LauncherPartLaunch.cpp:110`) + package `libraries/launcher/org/multimc/*.java` + `System.setProperty("multimc.instance.title"/"multimc.instance.icon")`. ⚠️ Couplé : renommer casse la compat avec les instances existantes — décider et documenter.
- [ ] Coordonnées Maven générées : `NewComponentDialog.cpp:71`, `OneSixVersionFormat.cpp:348`, `PackProfile.cpp:1050,1067,1107`, `ATLPackInstallTask.cpp:273,301,395`.

### URLs runtime (services upstream)
- [ ] `CMakeLists.txt:82-83` NEWS/RSS multimc.org ; `:156` META_URL `meta.multimc.org` ; `:160` BUG_TRACKER URL.
- [ ] `BuildConfig.h:108,109,119` : `files.multimc.org/fmllibs`, `files.multimc.org/translations`, `TECHNIC_API_BUILD = "multimc"`.
- [ ] `TranslationsModel.cpp:577`, `AboutDialog.cpp:137` (patrons.txt), `UpdateDialog.cpp:37,51,92` (repo/API GitHub MultiMC), `LanguageSelectionWidget.cpp:51`, `PageContainer.cpp:210` (wiki).
- [ ] Clés API upstream (à remplacer par les siennes) : `CMakeLists.txt:157-159` (PasteEE / MSA client id / Imgur).
- [ ] Sentinel PasteEE `"multimc"` : `Application.cpp:797`, `GuiUtil.cpp:20`, `PasteEEPage.cpp:47,49,67`, `PasteEEPage.ui:43,119`.

### Docs & packaging
- [ ] `.github/ISSUE_TEMPLATE/*` : Discord multimc, wiki, issues upstream (5 fichiers).
- [ ] `launcher/package/rpm/MultiMC5.spec`, `launcher/package/ubuntu/multimc/` (desktop, metainfo, man, control, run.sh) : tout est nommé MultiMC.
- [ ] `doc/multimc.1.txt` (nom fichier, titre, URLs).
- [ ] `README.md` (reste intégralement upstream), `README.fork.md` (rebrand BerserkMC), `BUILD.md`, `COPYING.md:1` (titre), `changelog.md:1` (titre).
- [ ] `cmake/MacOSXBundleInfo.plist.in:40` : texte de permission macOS "MultiMC does not need access to your microphone".
- [ ] `cmake/UnitTest/test.rc:17` : `CompanyName "MultiMC Contributors"`.
- [ ] `launcher/updater/testdata/tst_DownloadTask-test_writeInstallScript.xml:9` : attend `MultiMC.exe` (sera `BerserkMC.exe`).

### Trailing logic/strings
- [ ] `NotificationChecker.cpp:42`, commentaires `JavaUtils.cpp:80,87,405`, commentaires de debug dans `InstanceImportTask.cpp:110-113`.

---

## P2 — Fonctionnalités incomplètes / UI QML morte

- [ ] **NewInstance : 3 onglets sur 4 sont des stubs** — `NewInstanceView.qml:2-5,255,585` : Modrinth / CurseForge / Importer = texte "Bientôt — Phase 7". Intégrer via cpp ou signaler clairement indisponible.
- [ ] **Installation du mod-loader incomplète** — `QmlBridge.cpp:401-520` : contradiction `Q_UNUSED(loader)` vs code qui installe ; instance ré-resolue **par nom** (collision si 2 instances même nom) ; `setComponentVersion` ne déclenche pas le téléchargement des libs ; `setIcon("default")` codé en dur ; `createVanillaInstance` retourne `false` quand même.
- [ ] **Source de vérité des versions dupliquée** — `NewInstanceView.qml:90-127` fetch `launchermeta.mojang.com` via XHR alors que le bridge résout via `metadataIndex()` cpp. Une version choisie peut ne pas se résoudre à la création ; pas de mode offline.
- [ ] **Bouton "Créer l'instance" jamais désactivé** — `NewInstanceView.qml:568-573` : peut tirer avec `selectedVersion` par défaut `"1.21"` avant chargement / nom vide.
- [ ] **Plusieurs champs bridge jamais consommés par l'UI** — `QmlBridge.cpp:192-194` (`stateText`, `ownsMinecraft`, `hasProfile`) ; `isRunning()` jamais appelé ; branches `openFolder` "central-mods"/"instances-root" jamais utilisées.
- [ ] **PageHeader.rightContent** — slot déclaré mais aucune vue ne l'utilise (`PageHeader.qml:17,92`).
- [ ] **Fonctions manquantes vs mockups** — `_mockups/B_main.html` : statusbar (Java + "à jour") absente ; logo dans la titlebar absent ; `E_settings.html` : sélecteur Thème absent, bouton refresh/detect Java à côté du champ JDK absent ; `D_add_instance.html` : champ recherche de version absent, tuile Add en pointillés absente (`InstanceCard.qml:37-45`).
- [ ] **"Dossiers" n'ouvre que le root** — `LibraryView.qml:96-129` malgré le pluriel ; pas de menu de dossiers.

---

## P3 — Build / packaging

- [ ] **Aucune CI** — `.github/` contient seulement des templates d'issues, aucun workflow GitHub Actions.
- [ ] **Sources dupliquées dans la liste UI** — `launcher/CMakeLists.txt:877-882` : `CustomCommands.ui`, `InstanceCardWidget.ui`, `MCModInfoFrame.ui` listés deux fois chacun.
- [ ] **Fichiers/hardcodes de build** — `CMakeLists.txt` référence `branding/multimc.rc`, `MultiMC.icns` (noms upstream) ; `TECHNIC_API_BUILD` ; version launcher figée `0.7.0` (vs texte UI "0.1.0").
- [ ] **Instructions de build obsolètes** — `BUILD.md` & `README.fork.md` : Qt 5.6, OpenSSL 1.0.2g, chemins `MultiMC-Offline`/`BerserkLauncher`. Le build réel cible Qt 5.15+ / QML.
- [ ] **Sous-modules** — `.gitmodules:1` nom `[submodule "depends/libnbtplusplus"]` mais path `libraries/libnbtplusplus` (incohérence de section). Vérifier `git submodule sync`.
- [ ] **Dépendance QML `QtGraphicalEffects`** non garantie au déploiement — `WelcomeView.qml:8`, `Icon.qml:6` (`ColorOverlay`). Si le module manque, toute l'UI échoue. (`Application.cpp:1489-1490` ne fait que logger.)
- [ ] **`qmldir` mort** — `launcher/qml/qmldir` déclare `module BerserkMC.Ui` + singleton mais le path `qrc:/qml` n'est jamais importé ; `Theme` est enregistré manuellement (`Application.cpp:1479-1480`).
- [ ] **Ressources inutilisées** — `qml/icons/chevron-down.svg` enregistré dans `qml.qrc:40` mais jamais référencé.

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
- [ ] **Valeurs codées en dur dans l'UI** — `Main.qml:33` ("QML PREVIEW"), `Main.qml:179` (toast dev "Bienvenue — UI Qt Quick active" à chaque lancement), `Toolbar.qml:11` (`"Karim_"`, `"K"`), `NewInstanceView.qml:24-25` (`"1.21"`, `"1.21 Vanilla"`), `Titlebar.qml:20` (ko-fi), `SettingsView.qml:589` ("BerserkMC 0.1.0").
- [ ] **Couleurs hardcodées hors thème** — `Titlebar.qml:66,74,125,134`, `AccountsView.qml`/`Toolbar.qml` (`#7ab1ff`), `NewInstanceView.qml` (`#ffa9a9`).
- [ ] **Commentaires stalés** — `QmlBridge.cpp:403` (contredit le code), `LibraryView.qml:2-3` ("Phase 3 mock data" alors que le modèle est réel).
- [ ] **`InstanceSidebar.qml:262,272`** : `contentY` mort ; **`InstanceCard.qml:44`** : tuile Add.
- [ ] **`qsTr()` sur chaîne dynamique** — `AccountsView.qml:543` intraduisible.
- [ ] **SEO/docs** : `SettingsView.qml:286` dit "sous launcher/java/" alors que c'est `APPLICATION->root()/JavaInstaller` (`JavaInstaller.cpp:34`).

---

## Notes

- Les headers de copyright `/* Copyright ... MultiMC Contributors */` (234 occurrences) sont **requis** par la licence Apache-2.0 → ne pas toucher.
- Le format d'instance `mmc-pack.json` (compat MultiMC) et l'enum `ModpackType::MultiMC` doivent être **conservés** pour la compatibilité.
- Dépendances ordonnées du rebrand : renommer la ressource multimc.qrc en premier (couple `CMakeLists`, `UpdateDialog.ui`, `main.cpp`, préfixes) puis le thème d'icônes, puis le branding, puis les URLs.