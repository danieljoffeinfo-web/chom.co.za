import { iconSpriteResponse } from '@chom/dashboard';

// The shared icon sprite (packages/dashboard/icons.svg), built once at build time.
export const dynamic = 'force-static';

export function GET() {
  return iconSpriteResponse();
}
