/// Local Supabase defaults (from `supabase start`).
abstract final class SupabaseTestConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_TEST_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_TEST_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.'
        'CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  static const password = 'TestPassword123!';

  static const ownerId = '11111111-1111-1111-1111-111111111111';
  static const memberId = '22222222-2222-2222-2222-222222222222';
  static const outsiderId = '33333333-3333-3333-3333-333333333333';

  static const goalId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  static const seedLogId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  static const ownerEmail = 'test.owner@tracketiv.local';
  static const memberEmail = 'test.member@tracketiv.local';
  static const outsiderEmail = 'test.outsider@tracketiv.local';

  static const adminId = '44444444-4444-4444-4444-444444444444';
  static const adminEmail = 'test.admin@tracketiv.local';

  static const groupId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  static const groupName = 'E2E Test Group';

  static const groupGoalId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  static const groupGoalTitle = 'E2E Group Steps Goal';

  static const templateId = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
  static const templateTitle = 'E2E Join Template';
}
