"use client"
import { useState } from "react"
import { useMutation } from "@tanstack/react-query"
import { generateReport } from "@/lib/api"
import toast from "react-hot-toast"
import ReactMarkdown from "react-markdown"

const reportTypes = [
  { id:"seo", label:"🔍 Auditoria SEO", desc:"Análise técnica, problemas e recomendações", color:"text-blue-400 border-blue-500/30 bg-blue-500/10" },
  { id:"ranking", label:"📊 Ranking de Termos", desc:"Keywords, posições e oportunidades", color:"text-green-400 border-green-500/30 bg-green-500/10" },
  { id:"monthly", label:"📅 Relatório Mensal", desc:"Resumo completo do mês com IA", color:"text-purple-400 border-purple-500/30 bg-purple-500/10" },
  { id:"social", label:"📱 Análise Social", desc:"Performance de redes sociais", color:"text-pink-400 border-pink-500/30 bg-pink-500/10" },
]

export default function ReportsPage() {
  const [content, setContent] = useState("")
  const [activeType, setActiveType] = useState("")
  const genMut = useMutation({
    mutationFn:(type:string)=>generateReport(type).then(r=>r.data),
    onSuccess:(data,type)=>{setContent(data.report);setActiveType(type);toast.success("Relatório gerado!")}
  })

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {reportTypes.map(rt=>(
          <button key={rt.id} onClick={()=>genMut.mutate(rt.id)} disabled={genMut.isPending}
            className={`p-4 rounded-xl border text-left transition-all hover:scale-105 disabled:opacity-50 ${rt.color} ${activeType===rt.id?"ring-2 ring-offset-1 ring-offset-slate-950 ring-current":""}`}>
            <p className="text-sm font-semibold mb-1">{rt.label}</p>
            <p className="text-xs opacity-70">{rt.desc}</p>
            {activeType===rt.id && genMut.isPending && <p className="text-xs mt-2 animate-pulse">Gerando com IA...</p>}
          </button>
        ))}
      </div>

      {genMut.isPending && (
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-12 text-center">
          <div className="text-4xl mb-4 animate-spin">⟳</div>
          <p className="text-sm text-slate-300">IA analisando seus dados...</p>
          <p className="text-xs text-slate-500 mt-1">Isso pode levar alguns segundos</p>
        </div>
      )}

      {content && !genMut.isPending && (
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-white">{reportTypes.find(r=>r.id===activeType)?.label}</h3>
            <button onClick={()=>navigator.clipboard.writeText(content).then(()=>toast.success("Copiado!"))}
              className="text-xs text-slate-400 hover:text-white border border-slate-700 px-2 py-1 rounded">📋 Copiar</button>
          </div>
          <div className="prose prose-invert prose-sm max-w-none">
            <ReactMarkdown>{content}</ReactMarkdown>
          </div>
        </div>
      )}
    </div>
  )
}