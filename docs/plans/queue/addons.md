# WannaQueue - Plan Addon

## Description

**WannaQueue** est un addon WoW pour l'extension Midnight (12.0) qui auto-accepte les role checks LFG.

Quand tu es dans un groupe et que le chef de groupe lance une recherche de donjon/raid via le Group Finder, tous les membres reçoivent un popup leur demandant de confirmer leur rôle (Tank/Healer/DPS). Cet addon accepte automatiquement ce popup sans intervention manuelle.

Equivalent de l'ancien WeakAura : https://wago.io/HyHjIHeKm

## Comment ça fonctionne

### Flux de fonctionnement

1. **Login** : WoW charge l'addon, initialise les SavedVariables, affiche un message de confirmation dans le chat
2. **Le leader queue** : Le chef de groupe clique sur "Rechercher" dans le Group Finder
3. **Role check popup** : L'event `LFG_ROLE_CHECK_SHOW` se déclenche chez tous les membres du groupe
4. **Auto-accept** : L'addon intercepte cet event et appelle `CompleteLFGRoleCheck(true)` qui accepte le role check avec les rôles déjà sélectionnés par le joueur
5. **Confirmation** : Un message s'affiche dans le chat pour confirmer l'auto-accept

### API WoW utilisée

| Élément | Type | Description |
|---------|------|-------------|
| `LFG_ROLE_CHECK_SHOW` | Event | Se déclenche quand le popup de role check apparaît |
| `CompleteLFGRoleCheck(true)` | Function | Accepte le role check avec les rôles actuels du joueur |
| `ADDON_LOADED` | Event | Se déclenche au chargement de l'addon, utilisé pour initialiser les SavedVariables |

### Note Midnight (12.0)

L'extension Midnight apporte des changements massifs à l'API addons (restrictions combat, "Secret Values"), mais les fonctions LFG/queue UI ne sont **pas affectées**. `CompleteLFGRoleCheck` reste disponible comme fonction globale.

## Structure de l'addon

```
wow-addon/
├── WannaQueue/
│   ├── WannaQueue.toc    # Manifeste addon (metadata, interface version, fichiers)
│   ├── WannaQueue.lua    # Toute la logique (~50 lignes)
│   └── README.md         # Documentation addon
├── docs/plans/queue/
│   └── addons.md         # Ce fichier
└── README.md             # README principal du repo
```

## Fichiers

### WannaQueue.toc

Le fichier TOC est le manifeste que WoW lit au lancement. Il déclare :
- `Interface: 120001` — version Midnight
- `SavedVariables: WannaQueueDB` — persiste l'état enabled/disabled entre sessions
- Liste des fichiers Lua à charger

### WannaQueue.lua

Contient toute la logique :
- **Initialisation** : Sur `ADDON_LOADED`, merge les defaults dans `WannaQueueDB`
- **Auto-accept** : Sur `LFG_ROLE_CHECK_SHOW`, appelle `CompleteLFGRoleCheck(true)` si enabled
- **Slash commands** : `/wq` et `/wannaqueue` pour toggle on/off
- **SavedVariables** : `WannaQueueDB.enabled` persiste entre sessions (défaut: `true`)

## Commandes

| Commande | Action |
|----------|--------|
| `/wq` | Toggle l'auto-accept on/off |
| `/wannaqueue` | Alias de `/wq` |

## Installation

1. Cloner le repo
2. Copier le dossier `WannaQueue/` dans `World of Warcraft/_retail_/Interface/AddOns/`
3. Relancer WoW ou `/reload`

## Cas limites

- **Combat** : `CompleteLFGRoleCheck` n'est pas une action protégée, fonctionne même en combat
- **Pas de rôle sélectionné** : Si le joueur n'a jamais configuré ses rôles LFG, l'accept peut échouer silencieusement — il gère manuellement cette unique fois
- **Appels multiples** : `CompleteLFGRoleCheck(true)` sans role check pending = no-op, aucun risque
- **Mise à jour API** : Si `CompleteLFGRoleCheck` migre vers `C_LFGInfo.CompleteLFGRoleCheck`, c'est un changement d'une seule ligne

## Vérification / Test

1. Login → message "WannaQueue loaded" dans le chat
2. `/wq` → affiche "Disabled", `/wq` encore → affiche "Enabled"
3. En groupe, le leader queue pour un donjon → role check auto-accepté + message chat
4. `/reload` → l'état enabled/disabled persiste
