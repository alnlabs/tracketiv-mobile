import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fixed pixel sizes — do not rely on Material textTheme slots for hierarchy.
abstract final class TypeScale {
  static const appBarTitle = 20.0;
  static const sheetTitle = 17.0;
  static const emptyStateTitle = 17.0;
  static const sectionTitle = 13.0;
  static const cardTitle = 14.0;
  static const cardTitleSmall = 13.0;
}

abstract final class AppTypography {
  static TextStyle appBarTitle(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return GoogleFonts.dmSans(
      fontSize: TypeScale.appBarTitle,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.3,
      color: color,
    );
  }

  static TextStyle appBarSubtitle(BuildContext context) {
    return GoogleFonts.dmSans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  static TextStyle sheetTitle(BuildContext context) {
    return GoogleFonts.dmSans(
      fontSize: TypeScale.sheetTitle,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  static TextStyle emptyStateTitle(BuildContext context) {
    return GoogleFonts.dmSans(
      fontSize: TypeScale.emptyStateTitle,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  static TextStyle sectionTitle(BuildContext context) {
    return GoogleFonts.dmSans(
      fontSize: TypeScale.sectionTitle,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  /// Primary title on list cards and grid tiles — always below [appBarTitle].
  static TextStyle cardTitle(BuildContext context, {FontWeight weight = FontWeight.w500}) {
    return GoogleFonts.dmSans(
      fontSize: TypeScale.cardTitle,
      fontWeight: weight,
      height: 1.2,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  static TextStyle? cardHeader(BuildContext context) => cardTitle(context, weight: FontWeight.w600);

  static TextStyle? authorName(BuildContext context) => cardTitle(context, weight: FontWeight.w600);

  static TextStyle? authorNameDetail(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);

  static TextStyle? profileName(BuildContext context) =>
      cardTitle(context, weight: FontWeight.w600);

  static TextStyle? meta(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          );

  static TextStyle? metaMuted(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

  static TextStyle badge(BuildContext context, {Color? color}) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          );

  static TextStyle? metricOnCard(BuildContext context, {Color? color}) =>
      Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: -0.5,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          );

  static TextStyle? metricHero(BuildContext context, {Color? color}) =>
      Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: -0.5,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          );

  static TextStyle? metricUnit(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

  static TextStyle? metricTrend(BuildContext context, {required Color color}) =>
      Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          );

  static TextStyle? metricBaseline(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

  static TextStyle? statValue(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1,
          );

  static TextStyle? statLabel(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          );

  static TextStyle? cardBody(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium;

  static TextStyle? cardBodyBold(BuildContext context) =>
      cardTitle(context, weight: FontWeight.w600);

  static TextStyle avatarInitial({bool large = false}) => TextStyle(
        fontSize: large ? 16 : 12,
        fontWeight: FontWeight.w600,
      );

  static TextStyle? actionCount(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
}
