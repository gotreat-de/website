import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "GoTreat – Know it. Move it.",
  description: "Digitale Zusammenarbeit für Arztpraxen.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="de" className="h-full antialiased">
      <body className="flex min-h-full flex-col">{children}</body>
    </html>
  );
}
