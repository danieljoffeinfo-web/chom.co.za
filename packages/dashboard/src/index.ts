export { ComingSoon } from './coming-soon';
export { Icon, type IconName } from './icon';
import { ICON_SPRITE } from './sprite';

export { ICON_SPRITE };

/**
 * The response for an app's /icons.svg route:
 *   export const dynamic = 'force-static';
 *   export const GET = () => iconSpriteResponse();
 */
export function iconSpriteResponse(): Response {
  return new Response(ICON_SPRITE, {
    headers: {
      'content-type': 'image/svg+xml; charset=utf-8',
      'cache-control': 'public, max-age=3600, stale-while-revalidate=86400',
    },
  });
}
