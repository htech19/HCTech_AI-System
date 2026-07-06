import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'HC Tech AI System v2.1',
  description: 'Plataforma Hibrida Local/Online de IA para Assistencias Tecnicas',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className="dark">
      <body>{children}</body>
    </html>
  );
}