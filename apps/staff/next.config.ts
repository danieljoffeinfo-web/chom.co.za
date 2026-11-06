import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Shared workspace packages ship TypeScript source; let Next compile them.
  transpilePackages: ['@chom/tokens', '@chom/api'],
  reactStrictMode: true,
  // Keep pages already seen (or loaded in the background) for 5 minutes, so switching
  // tabs doesn't wait on a round trip to the server in Dublin every time.
  experimental: {
    staleTimes: { dynamic: 300, static: 300 },
  },
  // The icon sprite: let browsers keep it for a day instead of re-checking on every page.
  async headers() {
    return [
      {
        source: '/icons.svg',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=86400, stale-while-revalidate=604800' },
        ],
      },
    ];
  },
};

export default nextConfig;
