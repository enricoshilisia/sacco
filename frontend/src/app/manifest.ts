import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "SACCO Platform",
    short_name: "SACCO",
    description: "Multi-tenant SACCO management platform for Kenya and Tanzania",
    start_url: "/",
    display: "standalone",
    orientation: "portrait",
    background_color: "#f5f9f6",
    theme_color: "#1f7a40",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
      {
        src: "/icons/icon-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
  };
}
