import '../../../core/constants/app_constants.dart';

class LegalSection {
  const LegalSection({this.heading, required this.body});

  final String? heading;
  final String body;
}

abstract final class LegalContent {
  static const about = [
    LegalSection(
      heading: 'What is Tracketiv?',
      body:
          '${AppConstants.appName} helps you build habits and reach goals — solo or with friends. '
          'Track daily logs, follow progress on a feed, react to wins, and stay accountable in groups.',
    ),
    LegalSection(
      heading: 'Core features',
      body:
          '• Personal and group goals (weight, steps, habits, and more)\n'
          '• Daily, weekly, or custom logging cadence\n'
          '• Social feed with reactions and comments\n'
          '• Push reminders and in-app notifications\n'
          '• Profile and activity stats',
    ),
    LegalSection(
      heading: 'Contact',
      body: 'Questions or feedback: ${AppConstants.feedbackEmail}',
    ),
  ];

  static const disclaimer = [
    LegalSection(
      heading: 'General information only',
      body:
          '${AppConstants.appName} is a habit and goal-tracking tool. It does not provide medical, '
          'nutritional, psychological, or professional health advice.',
    ),
    LegalSection(
      heading: 'Your responsibility',
      body:
          'Always consult a qualified professional before starting or changing any health, fitness, '
          'or weight-loss program. You are solely responsible for how you use the app and any '
          'decisions you make based on your tracked data.',
    ),
    LegalSection(
      heading: 'No warranties',
      body:
          'The app and its content are provided "as is" without warranties of any kind. We do not '
          'guarantee accuracy of third-party data (including quotes or templates) or uninterrupted service.',
    ),
    LegalSection(
      heading: 'Limitation of liability',
      body:
          'To the fullest extent permitted by law, ${AppConstants.appName} and its operators are not '
          'liable for any damages arising from your use of the app.',
    ),
  ];

  static const privacyPolicy = [
    LegalSection(
      heading: 'Overview',
      body:
          'This policy describes how ${AppConstants.appName} handles information when you use the mobile app. '
          'By using the app you agree to this policy.',
    ),
    LegalSection(
      heading: 'Information we collect',
      body:
          '• Account data: email, username, display name, profile details you provide\n'
          '• Goal and log data: targets, entries, notes, and group membership\n'
          '• Social data: reactions, comments, and feed activity\n'
          '• Device data: push notification tokens when you enable notifications\n'
          '• Feedback you voluntarily send us',
    ),
    LegalSection(
      heading: 'How we use data',
      body:
          'We use your data to operate the service: authenticate you, store your goals and logs, '
          'show your feed and group activity, send reminders and notifications you configure, '
          'and improve the product.',
    ),
    LegalSection(
      heading: 'Storage & security',
      body:
          'Data is stored using Supabase (hosted PostgreSQL and authentication). We apply '
          'industry-standard access controls via row-level security. No method of transmission '
          'or storage is 100% secure.',
    ),
    LegalSection(
      heading: 'Friends & feed',
      body:
          'If you accept a friend request, your friend can see logs from all of your goals in '
          'their feed, including solo goals. Group goal activity may also be visible to friends '
          'who are not in that group. You can remove a friend at any time from Explore → Connect.',
    ),
    LegalSection(
      heading: 'Third parties',
      body:
          'We use Supabase for backend services and Firebase Cloud Messaging for push delivery '
          '(when enabled). Feed add-ons (e.g. daily quotes) may use server-hosted content.',
    ),
    LegalSection(
      heading: 'Your choices',
      body:
          'You can update profile information in the app, disable notifications in system settings, '
          'and request account deletion by contacting ${AppConstants.feedbackEmail}.',
    ),
    LegalSection(
      heading: 'Contact',
      body: 'Privacy questions: ${AppConstants.feedbackEmail}',
    ),
  ];
}
