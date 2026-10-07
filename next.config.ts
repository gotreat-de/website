import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Emit a self-contained server (.next/standalone) for the container image.
  output: "standalone",
};

export default nextConfig;
