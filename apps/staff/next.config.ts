import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Shared workspace packages ship TypeScript source; let Next compile them.
  transpilePackages: ['@chom/tokens', '@chom/api', '@chom/dashboard'],
  reactStrictMode: true,
  // Keep pages already seen (or loaded in the background) for 5 minutes, so switching
  // tabs doesn't wait on a round trip to the server in Dublin every time.
  experimental: {
    staleTimes: { dynamic: 300, static: 300 },
  },
};

export default nextConfig;
