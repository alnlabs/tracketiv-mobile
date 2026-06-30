-- Allow more reaction types on logs.

alter table public.log_reactions
  drop constraint if exists log_reactions_emoji_type_check;

alter table public.log_reactions
  add constraint log_reactions_emoji_type_check
  check (
    emoji_type in (
      'like',
      'celebrate',
      'support',
      'fire',
      'love',
      'cheer',
      'star',
      'clap',
      'hundred',
      'rocket',
      'wow',
      'laugh'
    )
  );
