"use client"
import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { getAIStatus } from "@/lib/api"
import { useAppStore } from "@/store/useAppStore"
import toast from "react-hot-toast"

const pageNames: Record<string, string> = {
  dashboard: "📊 Dashboard", agents: "🤖 Agentes IA", kanban: "📋 Kanban",
  seo: "🔍 SEO Manager", social: "📱 Social Hub", maps: "📍 Google Maps",
  knowledge: "📚 Base de Conhecimento", reports: "📈 Relatórios",
  automation: "⚙️ Automação 24/7", settings: "🛠️ Configurações",
}

const provConfig = {
  ollama: { label: "🦙 Ollama Local", color: "text-green-400 border-green-400/30 bg-green-400/10" },
  openai: { label: "🟢 OpenAI GPT", color: "text-blue-400 border-blue-400/30 bg-blue-400/10" },
  anthropic: { label: "🟣 Claude AI", color: "text-purple-400 border-purple-400/30 bg-purple-400/10" },
}

export default function Header() {
  const { selectedProvider, setSelectedProvider, currentPage } = useAppStore()
  const [open, setOpen] = useState(false)
  
  const { data } = useQuery({ queryKey: ["ai-status"], queryFn: () => getAIStatus().then(r => r.data), refetchInterval: 30000 })
  const providers = data?.providers || []
  const cur = provConfig[selectedProvider]

  const changeProvider = (p: "ollama" | "openai" | "anthropic") => {
    const info = providers.find((x: any) => x.provider === p)
    if (!info?.available) {
      toast.error(`${provConfig[p].label} não disponível. Configure no .env`)
      return
    }
    setSelectedProvider(p)
    setOpen(false)
    toast.success(`IA: ${provConfig[p].label}`)
  }

  return (
    <header className="h-16 bg-slate-900 border-b border-slate-800 flex items-center justify-between px-6 flex-shrink-0">
      <div>
        <h1 className="text-lg font-semibold text-white">{pageNames[currentPage] || "Dashboard"}</h1>
        <p className="text-xs text-slate-400">HC Tech AI System v2.1</p>
      </div>
      
      <div className="relative">
        <button onClick={() => setOpen(!open)}
          className={`flex items-center gap-2 px-3 py-2 rounded-lg border text-sm font-medium ${cur.color}`}>
          {cur.label} <span className="opacity-60">▼</span>
        </button>
        
        {open && (
          <>
            <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
            <div className="absolute right-0 top-full mt-2 w-72 bg-slate-800 border border-slate-700 rounded-xl shadow-2xl z-50 overflow-hidden">
              <div className="p-3 border-b border-slate-700">
                <p className="text-xs font-semibold text-slate-400 uppercase">🤖 Selecionar IA</p>
              </div>
              {(["ollama", "openai", "anthropic"] as const).map(pk => {
                const pc = provConfig[pk]
                const st = providers.find((x: any) => x.provider === pk)
                return (
                  <button key={pk} onClick={() => changeProvider(pk)}
                    className={`w-full flex items-center gap-3 px-4 py-3 hover:bg-slate-700 transition-colors ${selectedProvider === pk ? "bg-slate-700" : ""}`}>
                    <div className="flex-1 text-left">
                      <p className={`text-sm font-medium ${pc.color.split(" ")[0]}`}>{pc.label}</p>
                      <p className="text-xs text-slate-400">{st?.model || "Não configurado"} {pk === "ollama" ? "• Local • Grátis" : ""}</p>
                    </div>
                    <span className={`text-xs ${st?.available ? "text-green-400" : "text-red-400"}`}>
                      {st?.available ? "✓ Online" : "✗ Offline"}
                    </span>
                    {selectedProvider === pk && <span className="text-xs text-blue-400 font-bold">Ativo</span>}
                  </button>
                )
              })}
              <div className="p-3 border-t border-slate-700 text-center">
                <p className="text-xs text-slate-500">🔒 Ollama = 100% privado no seu PC</p>
              </div>
            </div>
          </>
        )}
      </div>
    </header>
  )
}