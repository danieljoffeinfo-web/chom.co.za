import { logo } from '@chom/tokens';

/**
 * The Chom logo ("chom."), drawn in the current text colour so it follows the theme.
 * Sized by height; the width follows the logo's shape.
 */
export function Logo({ height = 26, className }: { height?: number; className?: string }) {
  return (
    <svg
      className={className}
      viewBox={logo.viewBox}
      height={height}
      width={Math.round(height * logo.ratio)}
      role="img"
      aria-label="Chom"
      style={{ display: 'block' }}
    >
      <g fill="currentColor">
        {logo.glyphs.map((g) => (
          <path key={g.x} transform={`translate(${g.x} ${g.y})`} d={g.d} />
        ))}
      </g>
    </svg>
  );
}
