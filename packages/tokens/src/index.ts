/**
 * Chom design tokens.
 *
 * The single source of truth for colour, type, spacing and radius across the
 * web app (via the generated CSS variables in ../tokens.css) and the mobile
 * app (by importing these objects directly).
 *
 * Values match the live learner app: navy #282B4A as the main colour,
 * vanilla #EEEBDA as the background, light mode by default and dark mode
 * opt-in.
 */

export const palette = {
  navy: '#282B4A',
  navyRaised: '#33375C',
  navyLine: '#464A70',
  navySoft: '#3C4068',
  navyHover: '#383C63',
  vanilla: '#EEEBDA',
  vanillaRaised: '#F7F5EB',
  vanillaLine: '#DCD8C3',
  vanillaSoft: '#E4E0CB',
  slate: '#5F6178',
  slateLight: '#ABA9B8',
} as const;

export type ColorRole =
  | 'background'
  | 'surface'
  | 'text'
  | 'textMuted'
  | 'border'
  | 'subtle'
  | 'primary'
  | 'onPrimary'
  | 'primaryHover'
  | 'highlight';

export type ColorScheme = Record<ColorRole, string>;

/** Light is the default theme. */
export const light: ColorScheme = {
  background: palette.vanilla,
  surface: palette.vanillaRaised,
  text: palette.navy,
  textMuted: palette.slate,
  border: palette.vanillaLine,
  subtle: palette.vanillaSoft,
  primary: palette.navy,
  onPrimary: palette.vanilla,
  primaryHover: palette.navyHover,
  highlight: palette.vanillaLine,
};

/** Dark mode is opt-in from Settings. Navy and vanilla swap roles. */
export const dark: ColorScheme = {
  background: palette.navy,
  surface: palette.navyRaised,
  text: palette.vanilla,
  textMuted: palette.slateLight,
  border: palette.navyLine,
  subtle: palette.navySoft,
  primary: palette.vanilla,
  onPrimary: palette.navy,
  primaryHover: palette.vanillaLine,
  highlight: palette.navyLine,
};

export const colors = { light, dark } as const;

export const fontFamily = {
  /** Web self-hosts Inter Tight. Mobile loads four weights from @expo-google-fonts/inter-tight. */
  sans: '"Inter Tight", Inter, system-ui, sans-serif',
} as const;

/** Inter Tight weights in use. Avoid light weights. */
export const fontWeight = {
  medium: '500',
  semibold: '600',
  bold: '700',
  extrabold: '800',
} as const;

/** Type scale for screens (half the slide sizes in the Chom design system). */
export const textStyles = {
  display: { fontSize: 64, lineHeight: 64, fontWeight: fontWeight.extrabold, letterSpacing: -2 },
  title: { fontSize: 28, lineHeight: 31, fontWeight: fontWeight.extrabold, letterSpacing: -0.5 },
  heading: { fontSize: 18, lineHeight: 23, fontWeight: fontWeight.extrabold, letterSpacing: -0.2 },
  bodyStrong: { fontSize: 16, lineHeight: 22, fontWeight: fontWeight.bold, letterSpacing: 0 },
  body: { fontSize: 16, lineHeight: 24, fontWeight: fontWeight.medium, letterSpacing: 0 },
  label: { fontSize: 15, lineHeight: 18, fontWeight: fontWeight.bold, letterSpacing: -0.2 },
  caption: { fontSize: 13, lineHeight: 18, fontWeight: fontWeight.medium, letterSpacing: 0 },
} as const;

/** 8-point spacing scale. */
export const space = {
  0: 0,
  1: 4,
  2: 8,
  3: 12,
  4: 16,
  5: 20,
  6: 24,
  8: 32,
  10: 40,
  12: 48,
} as const;

export const radius = {
  sm: 8,
  md: 16,
  lg: 24,
  pill: 999,
} as const;

/** Minimum touch target, per accessibility guidance. */
export const minTouchTarget = 44;
