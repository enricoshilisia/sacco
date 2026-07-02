import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin("./src/i18n/request.ts");

const nextConfig: NextConfig = {
  // Next.js blocks cross-origin requests to dev-only assets by default
  // (DNS-rebinding protection). Each SACCO is reached via its own
  // subdomain (nairobi.localhost, dar.20.56.34.194.nip.io, ...), all of
  // which are "cross-origin" from the dev server's own point of view, so
  // they need explicit allowlisting here or dev-only requests (HMR, font
  // proxying, etc.) get a 403.
  allowedDevOrigins: [
    "localhost",
    "*.localhost",
    "20.56.34.194",
    "20.56.34.194.nip.io",
    "*.20.56.34.194.nip.io",
  ],
  async headers() {
    return [
      {
        source: "/sw.js",
        headers: [
          { key: "Content-Type", value: "application/javascript; charset=utf-8" },
          { key: "Cache-Control", value: "no-cache, no-store, must-revalidate" },
          { key: "Service-Worker-Allowed", value: "/" },
        ],
      },
    ];
  },
};

export default withNextIntl(nextConfig);
