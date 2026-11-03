import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Shared workspace packages ship TypeScript source; let Next compile them.
  transpilePackages: ['@chom/tokens', '@chom/api', '@chom/dashboard'],
  reactStrictMode: true,
};

export default nextConfig;
