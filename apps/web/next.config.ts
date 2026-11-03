import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Shared workspace packages ship TypeScript source; let Next compile them.
  transpilePackages: ['@chom/tokens', '@chom/api', '@chom/dashboard'],
  reactStrictMode: true,
  // The HTML prototypes (copied into public/ at build time) are served as folders.
  async rewrites() {
    return [
      { source: '/app', destination: '/app/index.html' },
      { source: '/teacher', destination: '/teacher/index.html' },
    ];
  },
  async redirects() {
    return [{ source: '/student/app', destination: '/app', permanent: false }];
  },
};

export default nextConfig;
