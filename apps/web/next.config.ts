import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Shared workspace packages ship TypeScript source; let Next compile them.
  transpilePackages: ['@chom/tokens', '@chom/api'],
  reactStrictMode: true,
  // The student dashboard (copied into public/ at build time) is served as a folder.
  async rewrites() {
    return [{ source: '/app', destination: '/app/index.html' }];
  },
};

export default nextConfig;
