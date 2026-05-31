/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: ["pg", "bcrypt"],
  },
};

module.exports = nextConfig;
