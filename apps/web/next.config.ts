import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Shared workspace packages ship TypeScript source; let Next compile them.
  transpilePackages: ['@chom/tokens', '@chom/api'],
  reactStrictMode: true,
};

export default nextConfig;
