# BodyX — Application iOS SwiftUI

## Structure du projet

```
BodyX/
├── App/
│   └── BodyXApp.swift              # Point d'entrée @main
├── Models/
│   └── Encounter.swift             # Modèle de données + enums (Gender, Context)
├── ViewModels/
│   └── EncounterViewModel.swift    # Logique métier, filtres, stats, persistence
├── Views/
│   ├── ContentView.swift           # TabView principale (4 onglets)
│   ├── ProfileView.swift           # Onglet Profil
│   ├── List/
│   │   ├── EncounterListView.swift # Liste principale + stats + filtres
│   │   └── EncounterRowView.swift  # Cellule d'une entrée
│   ├── Map/
│   │   └── MapView.swift           # Carte avec pins + carte de détail
│   ├── Stats/
│   │   └── StatsView.swift         # Statistiques & graphiques
│   ├── Detail/
│   │   └── EncounterDetailView.swift # Fiche détail + mini-carte
│   ├── Add/
│   │   └── AddEncounterView.swift  # Formulaire ajout/édition
│   └── Components/
│       ├── AvatarView.swift        # Avatar circulaire réutilisable
│       └── StarRatingView.swift    # Étoiles affichage + picker
└── Utils/
    └── ColorExtension.swift        # Palette couleurs + helpers
```

## Prérequis

- Xcode 15+
- iOS 17+ (cible de déploiement)
- Swift 5.9+

## Installation dans Xcode

1. Ouvre Xcode → **Create New Project** → **App**
2. Nom : `BodyX`, Interface : `SwiftUI`, Language : `Swift`
3. Supprime le fichier `ContentView.swift` généré par défaut
4. Ajoute tous les fichiers dans les groupes correspondants (clic droit → Add Files)
5. Dans `Assets.xcassets`, ajoute la couleur `AccentColor` → `#FF375F`
6. Dans `Info.plist`, ajoute la clé `Privacy - Location When In Use Usage Description`
7. Build & Run (⌘R)

## Fonctionnalités

- **Liste** — recherche, filtre par année, groupé par année, swipe to delete
- **Carte** — pins personnalisés par genre, carte de résumé au tap (style Snap Map)
- **Stats** — KPIs, distribution des notes, répartition par contexte
- **Profil** — personnalisation, récapitulatif, reset
- **Ajout/Édition** — formulaire complet avec géocodage automatique de la ville
- **Persistence** — sauvegarde locale via `UserDefaults` + `Codable`
