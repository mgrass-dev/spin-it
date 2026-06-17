# Spin it — Godot 4 Game

Ce projet Godot 4 utilise GDScript. Les tests sont écrits avec GUT.

## TDD — Rouge / Vert / Refactor

Pour toute nouvelle fonctionnalité ou bug fix, suis le cycle **Red-Green-Refactor** :

1. **Rouge** : écris d'abord le test qui décrit le comportement attendu et constate son échec
2. **Vert** : implémente le strict minimum pour faire passer le test
3. **Refactor** : nettoie le code sans casser les tests

## Tests

- Framework : GUT (`.gutconfig.json` → `res://test/unit/`)
- Les tests sont dans `test/unit/test_*.gd`
- Toute classe `extends GutTest`, utilise `assert_eq`, `assert_true`, `assert_not_null`, etc.
- Lancer les tests : ouvre le projet dans Godot → onglet GUT → "Run All", ou en CLI avec `godot --headless --addons/gut/gut_cmdln.gd`
- Un test doit être isolé : pas de dépendance entre tests
- Pour un bug fix, écrire le test qui reproduit le bug d'abord

## Conventions

- English only for all code, comments, commits, and communication (for consistency)
- GDScript snake_case pour variables/fonctions, PascalCase pour classes
- Les signaux sont préfixés par `signal `
- Utilise `@onready` pour les références de nœuds
- Les fichiers scène `.tscn` ont un script `.gd` associé du même nom dans `scripts/`
- Ne pas ajouter de commentaires sauf si nécessaire pour clarifier un edge case
