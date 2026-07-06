/** @type {import("next").NextConfig} */
const nextConfig = {
  reactStrictMode: false,
  env: {
    NEXT_PUBLIC_BACKEND_URL: process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000",
    NEXT_PUBLIC_APP_VERSION: "2.1.0",
  },
}
module.exports = nextConfig