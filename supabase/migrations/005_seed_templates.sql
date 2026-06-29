-- Phase 5: Seed predefined goal templates

insert into public.goal_templates (title, description, category, metric_type, metric_unit, cadence, default_target, icon)
values
  (
    'Weight Loss',
    'Reach your target weight with daily weigh-ins and group accountability.',
    'fitness',
    'weight',
    'kg',
    'daily',
    '{"target_value": 90, "duration_months": 3}'::jsonb,
    'monitor_weight'
  ),
  (
    'Daily Steps',
    'Walk 10,000 steps every day to stay active and healthy.',
    'fitness',
    'steps',
    'steps',
    'daily',
    '{"target_value": 10000}'::jsonb,
    'directions_walk'
  ),
  (
    'Water Intake',
    'Drink enough water daily to stay hydrated.',
    'health',
    'volume',
    'glasses',
    'daily',
    '{"target_value": 8}'::jsonb,
    'water_drop'
  ),
  (
    'Meditation',
    'Build a daily mindfulness habit with guided sessions.',
    'mindfulness',
    'duration',
    'minutes',
    'daily',
    '{"target_value": 15}'::jsonb,
    'self_improvement'
  ),
  (
    'Reading',
    'Read for at least 30 minutes each day.',
    'learning',
    'duration',
    'minutes',
    'daily',
    '{"target_value": 30}'::jsonb,
    'menu_book'
  ),
  (
    'Weekly Workout',
    'Complete at least 3 workouts per week.',
    'fitness',
    'count',
    'sessions',
    'weekly',
    '{"target_value": 3}'::jsonb,
    'fitness_center'
  ),
  (
    'Monthly Savings',
    'Save a set amount each month toward your financial goal.',
    'finance',
    'currency',
    'usd',
    'monthly',
    '{"target_value": 500}'::jsonb,
    'savings'
  ),
  (
    'Sleep Quality',
    'Track hours of sleep and aim for 7-8 hours nightly.',
    'health',
    'duration',
    'hours',
    'daily',
    '{"target_value": 8}'::jsonb,
    'bedtime'
  );
