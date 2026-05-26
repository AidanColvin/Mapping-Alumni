/** @type {import('next').NextConfig} */
const isProd = process.env.NODE_ENV === "production";

const nextConfig = {
  output: "export",
  basePath: isProd ? "/Mapping-Alumni" : "",
  assetPrefix: isProd ? "/Mapping-Alumni/" : "",
  images: { unoptimized: true },
  trailingSlash: true,
};

module.exports = nextConfig;
