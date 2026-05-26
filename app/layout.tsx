import type { Metadata } from "next";
import "../styles/globals.css";

export const metadata: Metadata = {
  title: "AlumniMap",
  description: "Discover where university alumni work and lead.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-gray-50 text-gray-900 min-h-screen">{children}</body>
    </html>
  );
}
