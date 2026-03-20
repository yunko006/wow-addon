# PIGlow - Plan & Idees

## Contexte - Restrictions Midnight (12.0)

| Systeme | Statut a Midnight | Impact |
|---|---|---|
| **UNIT_AURA** | Secret Values en combat | On ne peut PAS lire le spell ID/nom/duree en encounter |
| **CLEU** | **Supprime** | Plus de COMBAT_LOG_EVENT_UNFILTERED |
| **SendAddonMessage** | **Bloque pendant les encounters** (AddOnMessageLockdown) | OK entre les pulls |
| **Cooldowns allies** | Inaccessible | `GetSpellCooldown` = self only, pas d'API pour les CDs des autres |

**Conclusion** : on ne peut rien tracker dynamiquement en combat. Mais on peut **calculer des timers statiques** a partir de donnees connues.

---

## Concept : PI Timer Calculator

### Principe

L'addon ne detecte rien en combat. A la place, il **calcule mathematiquement** les meilleurs moments pour PI en fonction du CD du spell principal de la cible choisie.

Reference : [Google Sheet PI Targets](https://docs.google.com/spreadsheets/u/0/d/1exJeu5eVe4bTmyg3WFx5PTxIWvDLi0j-WW-XWpGoG88/htmlview?pli=1&pru=AAABnSIdCl0*pFGgMGAhBE1nb3CvXiw5GQ#gid=1169345301)

### Logique de calcul

```
Donnees d'entree :
- CD de PI = 120s (2min)
- CD du spell cible = variable (ex: 45s pour un DK)

Calcul :
- PI #1 : toujours au pull (0:00)
- PI #2 : prochain alignement apres 120s
  → CD cible 45s : uptimes a 0, 45, 90, 135...
  → Premier uptime >= 120s = 135s (45 * 3)
  → PI #2 a 2:15
- PI #3 : prochain alignement apres 135 + 120 = 255s
  → Uptimes : 180, 225, 270...
  → Premier >= 255s = 270s (45 * 6)
  → PI #3 a 4:30
- etc.

Formule generique :
  pi_time[1] = 0
  pi_time[n] = premier multiple du CD cible >= pi_time[n-1] + CD_PI
```

### Flow d'utilisation

```
AVANT LE PULL
===========================================================

1. Le pretre ouvre le menu PIGlow (slash command ou minimap)
2. Il choisit un joueur dans son raid/groupe
3. L'addon detecte la spec du joueur (via inspect)
   OU le pretre choisit manuellement la spec/spell
4. L'addon affiche le planning calcule :
   "PI #1 → Pull (0:00)"
   "PI #2 → 2:15"
   "PI #3 → 4:30"
5. Le pretre valide

AU PULL (detection du debut de combat)
===========================================================

6. Detection via ENCOUNTER_START (raid) ou entree en combat (PLAYER_REGEN_DISABLED)
7. Les timers demarrent

PENDANT LE COMBAT
===========================================================

8. A chaque fenetre de PI, une ALERTE apparait :
   → Grosse icone PI au centre de l'ecran
   → Texte "PI → NomDuJoueur!"
   → Son d'alerte (optionnel)
   → L'alerte reste X secondes puis disparait

9. Optionnel : une petite barre/timer visible en permanence
   qui montre le countdown jusqu'a la prochaine PI

FIN DE COMBAT
===========================================================

10. Timers reset
11. Pret pour le prochain pull
```

---

## Database des specs/spells

L'addon embarque une table de donnees avec les CDs principaux par spec :

```lua
PIGlow.SpellDB = {
    -- Death Knight
    ["DEATHKNIGHT-Unholy"] = {
        name = "Army of the Dead",
        cd = 120,   -- ou Apocalypse 45s?
    },
    ["DEATHKNIGHT-Frost"] = {
        name = "Pillar of Frost",
        cd = 60,
    },
    -- Demon Hunter
    ["DEMONHUNTER-Havoc"] = {
        name = "Metamorphosis",
        cd = 120,
    },
    -- Mage
    ["MAGE-Fire"] = {
        name = "Combustion",
        cd = 120,
    },
    ["MAGE-Arcane"] = {
        name = "Arcane Surge",
        cd = 90,
    },
    -- Warlock
    ["WARLOCK-Demonology"] = {
        name = "Tyrant",
        cd = 60,
    },
    -- etc. pour chaque spec DPS
}
```

Cette table peut etre mise a jour a chaque patch sans toucher au code principal.

---

## Interface utilisateur

### Menu principal - 2 tabs

Le menu a **2 onglets** : un mode automatique (calcul par spec) et un mode manuel (timings custom).

#### Tab 1 : Auto (par spec)

Selection d'un joueur + auto-calcul des timings en fonction de sa spec.

```
┌─────────────────────────────────────────────┐
│ PIGlow          [Auto] [Manuel]             │
│─────────────────────────────────────────────│
│                                             │
│ Cible : [Dropdown joueurs raid/groupe]      │
│ Spec  : Frost DK (auto-detect)             │
│ Spell : Pillar of Frost (60s)              │
│                                             │
│ Planning calcule :                          │
│  PI #1 → 0:00  (pull)                      │
│  PI #2 → 2:00                              │
│  PI #3 → 4:00                              │
│  PI #4 → 6:00                              │
│                                             │
│ [Valider]  [Annuler]                       │
└─────────────────────────────────────────────┘
```

#### Tab 2 : Manuel (timings custom)

Pour les cas ou tu veux des timings precis (boss avec des phases specifiques,
CDs particuliers, strats guild, etc.). Tu choisis le joueur et tu entres
les timings a la main.

```
┌─────────────────────────────────────────────┐
│ PIGlow          [Auto] [Manuel]             │
│─────────────────────────────────────────────│
│                                             │
│ Cible : [Dropdown joueurs raid/groupe]      │
│                                             │
│ Timings PI :                                │
│  #1  [0:00 ] (pull)                        │
│  #2  [1:30 ]                               │
│  #3  [3:45 ]                               │
│  #4  [5:20 ]                               │
│  #5  [     ]                               │
│                                             │
│ [+ Ajouter]                                │
│                                             │
│ [Valider]  [Annuler]                       │
└─────────────────────────────────────────────┘
```

**Utilisation du mode manuel** :
- Tu tapes les timings en format M:SS (ex: "1:30", "3:45")
- Tu peux ajouter/supprimer des lignes avec [+ Ajouter] et un bouton X par ligne
- Utile pour s'adapter a un boss specifique (ex: PI a la phase 2 a 1:30, puis a chaque intermission)
- Les timings sont sauvegardes par boss (SavedVariables) pour ne pas les re-entrer a chaque pull

### Alerte en combat (quand c'est le moment de PI)

```
        ┌──────────────┐
        │   [Icone PI]  │
        │  PI → Anconi! │
        │   maintenant  │
        └──────────────┘
        (disparait apres 5s)
```

### Mini-timer permanent (optionnel)

```
┌────────────────────┐
│ PI → Anconi  01:23 │
│ ████████░░░░░░░░░░ │
└────────────────────┘
```

Petit cadre deplacable, toujours visible en combat, avec countdown jusqu'a la prochaine PI.

---

## Slash commands

```
/piglow              → ouvre le menu de selection
/piglow assign Nom   → assignation rapide (auto-detect spec)
/piglow clear        → retire l'assignation
/piglow timer        → toggle le mini-timer
/piglow test         → simule une alerte pour tester le visuel
```

---

## Detection du debut de combat

Plusieurs events possibles :

| Event | Quand | Fiabilite |
|---|---|---|
| `ENCOUNTER_START` | Debut d'un boss raid | Tres fiable, raid only |
| `PLAYER_REGEN_DISABLED` | Entree en combat | Marche partout mais trigger sur chaque pack de trash |
| `CHALLENGE_MODE_START` | Debut d'une cle M+ | Une seule fois au debut du donjon |

**Recommandation** : utiliser `ENCOUNTER_START` en raid, et `PLAYER_REGEN_DISABLED` en donjon/monde ouvert. Option dans les settings pour choisir.

---

## Plan d'implementation

### Phase 1 - Core (MVP)

1. **SpellDB** : table des specs/spells avec leurs CDs
2. **Calcul des timers** : fonction qui genere le planning PI pour une spec donnee
3. **Detection combat** : ENCOUNTER_START + PLAYER_REGEN_DISABLED
4. **Alerte visuelle** : frame centrale avec icone PI + nom du joueur
5. **Slash commands** : `/piglow assign Nom` pour assigner rapidement
6. **SavedVariables** : sauvegarder l'assignation entre sessions

### Phase 2 - UX

7. **Menu de selection** : dropdown avec les joueurs du raid
8. **Auto-detect spec** : via `C_Inspect` ou `GetSpecialization` avant le pull
9. **Mini-timer** : barre de countdown deplacable
10. **Son d'alerte** : jouer un son quand c'est le moment de PI

### Phase 3 - Avance

11. **Glow sur raid frames** : via LibGetFrame, glow sur la frame de la cible quand c'est le moment
12. **Multi-cible** : supporter le switch de cible PI mid-fight (si la cible meurt)
13. **Custom spells** : permettre a l'utilisateur d'ajouter ses propres spells/CDs
14. **Import depuis le Google Sheet** : copier-coller les donnees du sheet pour mettre a jour la DB

---

## Verifications techniques (resolues)

- [x] **C_Timer.After() en combat** : OK. Fonctionne normalement pendant les encounters. Pas affecte par Secret Values ni AddOnMessageLockdown. Parfait pour notre usage (alertes visuelles uniquement).
- [x] **C_Inspect en instance** : OK. NotifyInspect + GetInspectSpecialization fonctionnent dans les raids/donjons. Pas affectes par Secret Values. Limites classiques : portee, throttle (~6 req/10s), asynchrone (attendre INSPECT_READY).
- [x] **CD de PI** : toujours 2min fixe, pas de variante talent/item a gerer.

## Questions ouvertes

- [ ] Est-ce qu'on track aussi le CD reel de PI du pretre (au cas ou il rate un cast) ?
- [ ] Faut-il supporter d'autres buffs que PI ? (Innervate, etc.)
