"use client"
import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { getAIStatus } from "@/lib/api"
import { useAppStore } from "@/store/useAppStore"
import toast from "react-hot-toast"

export default function SettingsPage() {
  const { selectedProvider, setSelectedProvider } = useAppStore()
  const { data, refetch } = useQuery({ queryKey:["ai-status"], queryFn:()=>getAIStatus().then(r=>r.data) })
  const providers = data?.providers || []

  return (
    <div className="space-y-6 max-w-2xl">
      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-white mb-4">🤖 Provedores de IA</h3>
        <div className="space-y-3">
          {providers.map((p:any)=>(
            <div key={p.provider} className="flex items-center justify-between p-4 bg-slate-800/50 rounded-xl border border-slate-700">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <p className="text-sm font-medium text-white">
                    {p.provider==="ollama"?"🦙":p.provider==="openai"?"🟢":"🟣"} {p.name}
                  </p>
                  {p.local && <span className="text-xs bg-green-500/20 text-green-400 px-1.5 py-0.5 rounded">LOCAL</span>}
                  {p.free && <span className="text-xs bg-blue-500/20 text-blue-400 px-1.5 py-0.5 rounded">GRÁTIS</span>}
                </div>
                <p className="text-xs text-slate-400">Modelo: {p.model}</p>
                <p className="text-xs text-slate-500">{p.description}</p>
                {p.provider==="ollama" && p.models?.length>0 && (
                  <p className="text-xs text-green-400 mt-1">✓ Modelos: {p.models.join(", ")}</p>
                )}
              </div>
              <div className="flex items-center gap-3">
                <div className="text-center">
                  <div className={`w-2.5 h-2.5 rounded-full mx-auto ${p.available?"bg-green-400 animate-pulse":"bg-red-500"}`}/>
                  <p className="text-xs text-slate-400 mt-1">{p.available?"Online":"Offline"}</p>
                </div>
                {p.available && (
                  <button onClick={()=>{setSelectedProvider(p.provider);toast.success(`IA: ${p.name}`)}}
                    className={`text-xs px-3 py-1.5 rounded-lg border transition-colors ${selectedProvider===p.provider?"bg-blue-600 border-blue-500 text-white":"border-slate-600 text-slate-300 hover:bg-slate-700"}`}>
                    {selectedProvider===p.provider?"✓ Ativo":"Usar"}
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
        <button onClick={()=>refetch()} className="mt-3 w-full py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg text-xs transition-colors">
          🔄 Verificar Status
        </button>
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-white mb-4">⚙️ Sobre o Sistema</h3>
        <div className="space-y-3 text-sm">
          {[
            ["Sistema","HC Tech AI System"],["Versão","v2.1.0"],["Backend","Python FastAPI"],
            ["Frontend","Next.js 14"],["IA Local","Ollama + Llama 3.2:3B"],["Banco","SQLite (local)"],
          ].map(([k,v])=>(
            <div key={k} className="flex justify-between py-2 border-b border-slate-800 last:border-0">
              <span className="text-slate-400">{k}</span>
              <span className="text-white font-medium">{v}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-slate-900 border border-yellow-500/30 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-yellow-400 mb-3">🔒 Privacidade</h3>
        <div className="space-y-2 text-xs text-slate-300">
          {["✅ Ollama roda 100% local - zero dados na nuvem","✅ Banco SQLite armazenado no seu PC","✅ APIs online usadas apenas se configuradas","✅ Nenhum dado enviado automaticamente","✅ Chaves de API ficam apenas no .env local"].map(t=>(
            <p key={t}>{t}</p>
          ))}
        </div>
      </div>
    </div>
  )
}