import 'package:flutter_riverpod/flutter_riverpod.dart';

const catalogCategoryLabels = {
  'all': 'All',
  'fitness': 'Fitness',
  'health': 'Health',
  'nutrition': 'Nutrition',
  'mindfulness': 'Mindfulness',
  'learning': 'Learning',
  'finance': 'Finance',
  'productivity': 'Productivity',
};

final catalogCategoryFilterProvider = StateProvider<String>((ref) => 'all');
