// ----------------- sequence_generator_service.dart -----------------
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/result.dart';
import '../../../data/database/isar_service.dart';

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService.instance;
});
// We'll use an enum to specify which sequence we want to update
enum SequenceType { family, item }

class SequenceGeneratorService {
  final IsarService _isarService;

  SequenceGeneratorService(this._isarService);

  /// Atomically increments the sequence number for a given type and shop.
  /// This operation must be transactional to prevent race conditions.
  Future<Result<int>> getNextSequence(SequenceType type, String shopId) async {
    final key = type.name; // Use enum name as the Isar ID

    try {
      // Isar transactions guarantee atomicity and thread safety.
      final nextValue = await _isarService.getNextSequence(key, shopId);
      return Success(nextValue);
    } catch (e, stack) {
      return Error(DatabaseFailure(
        'Failed to generate sequence for $key in shop $shopId',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  Future<Result<List<int>>> getNextSequences(
    SequenceType type, 
    String shopId, 
    int count,
) async {
    final key = type.name; 

    if (count <= 0) {
        return const Success([]);
    }

    try {
        // Delegate the atomic bulk operation to the IsarService
        final sequenceList = await _isarService.getNextSequences(key, shopId, count); 
        return Success(sequenceList);
    } catch (e, stack) {
        // Catch any transaction or database failure
        return Error(DatabaseFailure(
            'Failed to generate $count sequences for $key in shop $shopId',
            exception: e as Exception?,
            stackTrace: stack,
        ));
    }
}

  // NOTE: You can add helper methods here if the final ID generation logic is complex,
  // but for now, we'll assume the final formatting (combining sequence + digits)
  // happens in the InventoryService using the static IdGenerator.
}

// ----------------- sequence_generator_provider.dart -----------------
final sequenceGeneratorProvider = Provider<SequenceGeneratorService>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return SequenceGeneratorService(isarService);
});