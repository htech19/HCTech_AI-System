import type { Metadata } from "next"
import { Inter } from "next/font/google"
import "./globals.css"

const inter = Inter({ subsets: ["latin"] })

export const metadata: Metadata = {
  title: "HC Tech AI System v2.1",
  description: "Plataforma Híbrida Local/Online de IA para Assistências Técnicas",
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body className={`${inter.className} bg-slate-950 text-slate-50 antialiased`}>
        {children}
      </body>
    </html>
  )
}