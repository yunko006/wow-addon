# PIGlow - Plan Addon

## Description

**PIGlow** est un addon WoW pour Midnight (12.0) qui ajoute un glow sur les raid frames quand un joueur te MP pendant un fight, pour t'indiquer à qui envoyer ta Power Infusion.

Compatible avec **n'importe quel addon de raid frames** (Blizzard, Grid2, Dander Frames, ElvUI, VuhDo, Cell, etc.) grâce à **LibGetFrame**.

## Comment ça fonctionne

### Flux principal

1. **Tu es en raid/donjon** avec ton prêtre
2. **Un joueur te MP** (whisper) pendant le fight pour demander ta PI
3. **L'addon détecte le whisper** via l'event `CHAT_MSG_WHISPER`
4. **L'addon identifie le sender** — les noms de joueurs ne sont PAS des Secret Values en Midnight, donc le nom reste lisible même en combat
5. **L'addon matche le sender** avec son raid frame via **LibGetFrame** (fonctionne avec n'importe quel addon de frames)
6. **Un glow apparaît** sur le raid frame du joueur via LibCustomGlow
7. **Le glow disparaît** après un timer configurable (défaut: 10 secondes) ou quand tu cast PI

### Logique de détection

- **Pendant un encounter actif** : le contenu du message peut être un Secret Value → l'addon glow sur **tout whisper** venant d'un membre du raid/groupe (car la seule raison de MP le prêtre en combat = demander PI)
- **Hors combat** : le contenu est lisible → l'addon vérifie que le message contient "PI" ou "power infusion" pour éviter les faux positifs
- **Fallback** : si le match raid frame échoue, afficher une alerte chat avec le nom du joueur

## API WoW utilisée

| Élément | Type | Description |
|---------|------|-------------|
| `CHAT_MSG_WHISPER` | Event | Détecte les whispers entrants (params: text, playerName, ...) |
| `UnitName(unit)` | Function | Récupère le nom d'un joueur depuis son unit ID |
| `GetNumGroupMembers()` | Function | Nombre de membres dans le groupe/raid |
| `Ambiguate(name, "none")` | Function | Convertit "Player-Realm" en "Player" pour comparaison |
| `InCombatLockdown()` | Function | Vérifie si on est en combat (pour la logique de filtrage) |
| `C_Timer.After(seconds, fn)` | Function | Timer pour retirer le glow |
| `UNIT_SPELLCAST_SUCCEEDED` | Event | Détecte quand tu cast PI pour retirer le glow |

## Bibliothèques utilisées

| Lib | Rôle | Pourquoi |
|-----|------|----------|
| **LibStub** | Gestionnaire de libs | Standard WoW, requis par les autres libs |
| **LibGetFrame-1.0** | Trouver le raid frame d'un unit | Compatible avec TOUS les addons de raid frames (Grid2, Dander Frames, Blizzard, ElvUI, VuhDo, Cell, oUF...) |
| **LibCustomGlow-1.0** | Effets de glow | Ajoute des glows sans taint sur n'importe quel frame |

### LibGetFrame — La clé de la compatibilité universelle

Au lieu d'itérer manuellement les CompactRaidFrames Blizzard (qui ne marcherait qu'avec les frames par défaut), on utilise LibGetFrame :

```lua
local LGF = LibStub("LibGetFrame-1.0")
local frame = LGF.GetFrame(unit)  -- Retourne le frame peu importe l'addon utilisé
```

LibGetFrame reconnaît automatiquement :
- Blizzard CompactRaidFrames
- Grid2 (priorité 9)
- Dander Frames
- ElvUI
- VuhDo
- HealBot
- oUF et dérivés
- Cell
- Et d'autres...

## Structure de l'addon

```
PIGlow/
├── PIGlow.toc                          # Manifeste addon
├── PIGlow.lua                          # Logique principale
├── Libs/
│   ├── LibStub/
│   │   └── LibStub.lua                 # Gestionnaire de bibliothèques
│   ├── CallbackHandler-1.0/
│   │   └── CallbackHandler-1.0.lua     # Requis par LibGetFrame
│   ├── LibGetFrame-1.0/
│   │   └── LibGetFrame-1.0.lua         # Détection universelle de frames
│   └── LibCustomGlow-1.0/
│       └── LibCustomGlow-1.0.lua       # Effets de glow
└── README.md
```

## Fichiers détaillés

### PIGlow.toc

```toc
## Interface: 120001
## Title: PIGlow
## Notes: Glow raid frames when someone whispers you for Power Infusion.
## Author: yunko006
## Version: 1.0.0
## SavedVariables: PIGlowDB
## OptionalDeps: Grid2, DandersFrames, ElvUI, VuhDo, Cell

Libs/LibStub/LibStub.lua
Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua
Libs/LibGetFrame-1.0/LibGetFrame-1.0.lua
Libs/LibCustomGlow-1.0/LibCustomGlow-1.0.lua
PIGlow.lua
```

### PIGlow.lua — Logique principale

#### A. Initialisation et SavedVariables

```lua
PIGlowDB = PIGlowDB or {}

local defaults = {
    enabled = true,
    glowDuration = 10,        -- secondes avant que le glow disparaisse
    glowColor = {1, 0.8, 0, 1}, -- couleur dorée
    filterKeyword = true,     -- filtrer par mot-clé hors combat
}

local LCG  -- LibCustomGlow
local LGF  -- LibGetFrame
local activeGlows = {}  -- tracking des glows actifs {[senderName] = frame}
```

#### B. Trouver le raid frame d'un joueur (universel)

```lua
local function FindUnitForPlayer(senderName)
    local shortName = Ambiguate(senderName, "none")
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return nil end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numMembers do
        local unit = prefix .. i
        if UnitName(unit) == shortName then
            return unit
        end
    end
    return nil
end

local function FindRaidFrame(senderName)
    local unit = FindUnitForPlayer(senderName)
    if not unit then return nil end

    -- LibGetFrame : fonctionne avec n'importe quel addon de raid frames
    local frame = LGF.GetFrame(unit)
    return frame, unit
end
```

#### C. Appliquer / retirer le glow

```lua
local function ApplyGlow(frame, senderName)
    local key = "piglow_" .. senderName
    LCG.PixelGlow_Start(frame, PIGlowDB.glowColor, 8, 0.25, nil, 2, 0, 0, false, key)
    activeGlows[senderName] = frame

    -- Timer auto-remove
    C_Timer.After(PIGlowDB.glowDuration, function()
        if activeGlows[senderName] then
            LCG.PixelGlow_Stop(frame, key)
            activeGlows[senderName] = nil
        end
    end)
end

local function ClearAllGlows()
    for senderName, frame in pairs(activeGlows) do
        LCG.PixelGlow_Stop(frame, "piglow_" .. senderName)
    end
    activeGlows = {}
end
```

#### D. Event handler whisper

```lua
-- Sur CHAT_MSG_WHISPER :
local shortName = Ambiguate(playerName, "none")

-- Vérifier que le sender est dans notre raid/groupe
local unit = FindUnitForPlayer(playerName)
if not unit then return end

-- Filtrage par mot-clé (hors combat seulement, car en combat le texte peut être secret)
if not InCombatLockdown() and PIGlowDB.filterKeyword then
    local lowerText = text:lower()
    if not (lowerText:find("pi") or lowerText:find("power infusion")) then
        return
    end
end

-- Appliquer le glow via LibGetFrame (compatible tous addons)
local frame = LGF.GetFrame(unit)
if frame then
    ApplyGlow(frame, shortName)
    print("|cffFFCC00PIGlow|r: " .. shortName .. " demande PI!")
else
    print("|cffFFCC00PIGlow|r: " .. shortName .. " demande PI! (frame non trouvé)")
end
```

#### E. Retirer le glow quand PI est cast

```lua
-- Sur UNIT_SPELLCAST_SUCCEEDED :
-- Si le caster est "player" et le spell est Power Infusion (spell ID: 10060)
-- → ClearAllGlows()
```

#### F. Slash commands

```lua
SLASH_PIGLOW1 = "/piglow"
SLASH_PIGLOW2 = "/pig"
-- /piglow              → toggle on/off
-- /piglow duration 15  → changer la durée du glow
```

## Dépendances

Toutes les libs sont **embarquées** dans le dossier `Libs/` :
- **LibStub** : https://www.curseforge.com/wow/addons/libstub
- **CallbackHandler-1.0** : https://www.curseforge.com/wow/addons/callbackhandler
- **LibGetFrame-1.0** : https://www.curseforge.com/wow/addons/libgetframe
- **LibCustomGlow-1.0** : https://www.curseforge.com/wow/addons/libcustomglow

Ou via `.pkgmeta` pour le packaging automatique :
```yaml
externals:
  Libs/LibStub:
    url: https://repos.curseforge.com/wow/libstub/trunk
  Libs/CallbackHandler-1.0:
    url: https://repos.curseforge.com/wow/callbackhandler/trunk/CallbackHandler-1.0
  Libs/LibGetFrame-1.0:
    url: https://github.com/mrbuds/LibGetFrame
  Libs/LibCustomGlow-1.0:
    url: https://github.com/nicholasgasior/LibCustomGlow
```

## Cas limites

- **Secret Values en combat** : le contenu du message peut être secret pendant un encounter → on accepte tout whisper d'un membre du raid en combat (pas de filtrage par mot-clé)
- **Même serveur vs cross-realm** : `Ambiguate()` gère la conversion "Player-Realm" → "Player"
- **Pas en groupe** : l'addon ignore les whispers si tu n'es pas en groupe/raid
- **Faux positifs en combat** : un MP random d'un raid member en combat sera interprété comme une demande de PI → acceptable car rare
- **Addon de frames non reconnu par LibGetFrame** : fallback message chat avec le nom du joueur
- **Multiple demandes** : si 2 joueurs MP en même temps, les 2 frames glow indépendamment (clé unique par sender)
- **Cast PI** : tous les glows actifs sont retirés quand tu cast Power Infusion

## Installation

1. Copier le dossier `PIGlow/` dans `World of Warcraft/_retail_/Interface/AddOns/`
2. Relancer WoW ou `/reload`

## Commandes

| Commande | Action |
|----------|--------|
| `/piglow` | Toggle on/off |
| `/pig` | Alias |
| `/piglow duration <sec>` | Durée du glow (défaut: 10s) |

## Vérification / Test

1. Login → message "PIGlow loaded" dans le chat
2. `/piglow` → toggle on/off
3. En raid avec Grid2/Dander Frames/Blizzard, demander à un ami de te MP "PI" → son raid frame glow
4. Attendre 10s → le glow disparaît
5. Cast Power Infusion → le glow disparaît immédiatement
6. En combat, n'importe quel whisper d'un raid member → glow (pas de filtrage mot-clé)
7. Tester avec différents addons de raid frames pour vérifier la compatibilité

## Séquence d'implémentation

1. Créer la structure de dossiers `PIGlow/` et `PIGlow/Libs/`
2. Télécharger et inclure LibStub, CallbackHandler, LibGetFrame et LibCustomGlow
3. Créer `PIGlow.toc`
4. Créer `PIGlow.lua` avec toute la logique
5. Créer `PIGlow/README.md`
6. Mettre à jour le README principal du repo
7. Tester en jeu avec Blizzard frames, Grid2 et Dander Frames
