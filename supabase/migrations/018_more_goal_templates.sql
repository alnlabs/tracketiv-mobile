-- Additional goal templates (safe to run after 005_seed_templates)

insert into public.goal_templates (title, description, category, metric_type, metric_unit, cadence, default_target, icon)
select * from (values
  (
    'Morning Run',
    'Build endurance with a daily run — track distance and stay consistent.',
    'fitness',
    'distance',
    'km',
    'daily',
    '{"target_value": 5}'::jsonb,
    'directions_run'
  ),
  (
    'Push-ups',
    'Strengthen your upper body with a daily push-up target.',
    'fitness',
    'count',
    'reps',
    'daily',
    '{"target_value": 50}'::jsonb,
    'fitness_center'
  ),
  (
    'Cycling',
    'Ride your bike regularly and log weekly distance.',
    'fitness',
    'distance',
    'km',
    'weekly',
    '{"target_value": 30}'::jsonb,
    'directions_bike'
  ),
  (
    'Yoga Practice',
    'Complete yoga sessions each week for flexibility and recovery.',
    'fitness',
    'count',
    'sessions',
    'weekly',
    '{"target_value": 3}'::jsonb,
    'self_improvement'
  ),
  (
    'Protein Intake',
    'Hit your daily protein goal to support muscle and recovery.',
    'nutrition',
    'weight',
    'g',
    'daily',
    '{"target_value": 120}'::jsonb,
    'restaurant'
  ),
  (
    'Calorie Tracking',
    'Log daily calories to stay aware of your intake.',
    'nutrition',
    'count',
    'kcal',
    'daily',
    '{"target_value": 2000}'::jsonb,
    'restaurant'
  ),
  (
    'No Added Sugar',
    'Avoid added sugar each day and build a cleaner eating habit.',
    'nutrition',
    'count',
    'days',
    'daily',
    '{"target_value": 1}'::jsonb,
    'no_food'
  ),
  (
    'Take Vitamins',
    'Remember your daily vitamins or supplements.',
    'health',
    'count',
    'doses',
    'daily',
    '{"target_value": 1}'::jsonb,
    'medication'
  ),
  (
    'Limit Screen Time',
    'Keep recreational screen time under a daily limit.',
    'health',
    'duration',
    'hours',
    'daily',
    '{"target_value": 2}'::jsonb,
    'phone_android'
  ),
  (
    'Stretching',
    'Spend a few minutes stretching every day to stay mobile.',
    'health',
    'duration',
    'minutes',
    'daily',
    '{"target_value": 10}'::jsonb,
    'accessibility_new'
  ),
  (
    'Gratitude Journal',
    'Write one thing you are grateful for each day.',
    'mindfulness',
    'count',
    'entries',
    'daily',
    '{"target_value": 1}'::jsonb,
    'edit_note'
  ),
  (
    'Breathwork',
    'Practice focused breathing to reduce stress and improve focus.',
    'mindfulness',
    'duration',
    'minutes',
    'daily',
    '{"target_value": 5}'::jsonb,
    'air'
  ),
  (
    'Digital Detox',
    'Take intentional time away from screens each day.',
    'mindfulness',
    'duration',
    'hours',
    'daily',
    '{"target_value": 1}'::jsonb,
    'phonelink_off'
  ),
  (
    'Language Practice',
    'Practice a new language daily with apps, books, or conversation.',
    'learning',
    'duration',
    'minutes',
    'daily',
    '{"target_value": 20}'::jsonb,
    'translate'
  ),
  (
    'Coding Practice',
    'Code every day to sharpen skills and build momentum.',
    'learning',
    'duration',
    'minutes',
    'daily',
    '{"target_value": 45}'::jsonb,
    'code'
  ),
  (
    'Listen to Podcasts',
    'Learn on the go with educational podcasts each week.',
    'learning',
    'duration',
    'minutes',
    'weekly',
    '{"target_value": 120}'::jsonb,
    'podcasts'
  ),
  (
    'No-Spend Challenge',
    'Track days without unnecessary spending each week.',
    'finance',
    'count',
    'days',
    'weekly',
    '{"target_value": 5}'::jsonb,
    'money_off'
  ),
  (
    'Emergency Fund',
    'Save toward a monthly emergency fund contribution.',
    'finance',
    'currency',
    'usd',
    'monthly',
    '{"target_value": 200}'::jsonb,
    'account_balance'
  ),
  (
    'Wake Up Early',
    'Build an early morning routine and log successful wake-ups.',
    'productivity',
    'count',
    'days',
    'daily',
    '{"target_value": 1}'::jsonb,
    'alarm'
  ),
  (
    'Deep Work',
    'Block focused work time without distractions each day.',
    'productivity',
    'duration',
    'minutes',
    'daily',
    '{"target_value": 90}'::jsonb,
    'timer'
  ),
  (
    'Inbox Zero',
    'Clear your inbox to zero at least once per week.',
    'productivity',
    'count',
    'times',
    'weekly',
    '{"target_value": 1}'::jsonb,
    'email'
  ),
  (
    'Household Chores',
    'Complete weekly cleaning and household tasks.',
    'productivity',
    'count',
    'tasks',
    'weekly',
    '{"target_value": 5}'::jsonb,
    'cleaning_services'
  ),
  (
    'Journal Writing',
    'Reflect and write in your journal a few times per week.',
    'mindfulness',
    'count',
    'entries',
    'weekly',
    '{"target_value": 3}'::jsonb,
    'book'
  ),
  (
    'Plank Hold',
    'Build core strength with a daily plank duration goal.',
    'fitness',
    'duration',
    'seconds',
    'daily',
    '{"target_value": 60}'::jsonb,
    'fitness_center'
  )
) as v(title, description, category, metric_type, metric_unit, cadence, default_target, icon)
where not exists (
  select 1 from public.goal_templates gt where gt.title = v.title
);
