# Balesuk POS AI Agent Instructions

## Project Overview
Balesuk is a Flutter-based Point of Sale (POS) system with a focus on multi-language support (Amharic/English) and offline-first architecture. The project follows a layered architecture with clear separation of concerns.

## Architecture

### App Structure
- `lib/app/` - Application entry points and routing
  - Separate entry points for admin (`main_admin.dart`) and user (`main_user.dart`) roles
  - Role-based routing with protected admin routes
- `lib/data/` - Data layer (repositories, models, database)
  - Uses Drift (SQLite) for local storage
  - Repository pattern with DAOs
- `lib/presentation/` - UI components and state management
  - Riverpod for state management
  - Screen-based organization under `screens/`
- `lib/core/` - Core utilities and services

### Key Patterns

1. **Repository Pattern**
Example from `catalog_repository.dart`:
```dart
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final catalogDao = database.catalogDao;
  final configDao = database.configDao; 
  return CatalogRepository(catalogDao, configDao);
});
```

2. **Money Handling**
- Always use the `Money` class from `core/money.dart` for currency operations
- Example:
```dart
final salePrice = Money(10.00);  // Not: double salePrice = 10.00
```

3. **ID Generation**
- Items use a composite ID system (FamilyID + ItemCode)
- Use `generateNextItemId()` in repositories when creating new items

4. **Localization**
- All user-facing strings should be localized
- Support for am (Amharic), en (English), om (Oromo), ti (Tigrinya)
- Strings defined in `assets/i18n/app_*.arb`

## Development Workflows

### Database Changes
1. Modify tables in `lib/data/db/tables/`
2. Update `drift_database.dart`
3. Run codegen: `flutter pub run build_runner build`

### Adding New Features
1. Start with the data layer (models, repository)
2. Add business logic providers in `presentation/providers`
3. Create UI components in `presentation/screens`
4. Update routing in `app/router.dart`

### Testing
- Repository tests should mock DAOs
- UI tests should use `ProviderScope` for dependency injection

## Integration Points
- SQLite database via Drift
- Flutter Riverpod for state management
- go_router for navigation
- Localization via .arb files

## Common Gotchas
1. Always use repository providers, never instantiate repositories directly
2. Money values must use the `Money` class to prevent floating-point errors
3. Admin features must be wrapped with `AdminLockScreen`
4. Offline-first: handle all operations without network dependency