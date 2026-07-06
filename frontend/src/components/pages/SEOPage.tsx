"use client"
import { useState } from "react"
import { useQuery, useMutation } from "@tanstack/react-query"
import { getSEOKeywords, getSEOHealth, generateSEOContent, runSEOAudit } from "@/lib/api"
import toast from "react-hot-toast"

export default function SEOPage() {
  const [keyword, setKeyword] = useState("")
  const [contentType, setContentType] = useState("blog_post")
  const [generated, setGenerated] = useState("")

  const { data: keywords = [] } = useQuery({ queryKey:["keywords"], queryFn:()=>getSEOKeywords().then(r=>r.data) })
  const { data: health } = useQuery({ queryKey:["seo-health"], queryFn:()=>getSEOHealth().then(r=>r.data) })

  const genMut = useMutation({
    mutationFn: () => generateSEOContent({keyword,content_type:contentType}).then(r=>r.data),
    onSuccess: (data) => { setGenerated(data.content); toast.success("Conteúdo gerado!") }
  })
  const auditMut = useMutation({
    mutationFn: () => runSEOAudit().then(r=>r.data),
    onSuccess: (data) => { setGenerated(data.audit); toast.success("Auditoria concluída!") }
  })

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-white">🔍 Keywords Ranqueadas</h3>
            <span className="text-xs text-slate-400">{(keywords as any[]).length} keywords</span>
          </div>
          <div className="space-y-2">
            {(keywords as any[]).map((k:any,i:number) => (
              <div key={k.id} className="flex items-center gap-4 p-3 bg-slate-800/50 rounded-lg hover:bg-slate-800 transition-colors">
                <span className="text-xs text-slate-500 w-5">{i+1}</span>
                <div className="flex-1">
                  <p className="text-sm text-white font-medium">{k.keyword}</p>
                  <p className="text-xs text-slate-500">Vol: {k.volume.toLocaleString()} • Dif: {k.difficulty}%</p>
                </div>
                <div className="text-center">
                  <p className="text-lg font-bold text-white">#{k.position}</p>
                  <p className="text-xs text-slate-400">posição</p>
                </div>
                <div className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                  k.trend==="up"?"bg-green-500/20 text-green-400":k.trend==="down"?"bg-red-500/20 text-red-400":"bg-slate-700 text-slate-400"}`}>
                  {k.trend==="up"?"↑":k.trend==="down"?"↓":"→"}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-4">
          <div className="bg-slate-900 border border-slate-800 rounded-xl p-6 text-center">
            <p className="text-xs text-slate-400 mb-2">SEO Health Score</p>
            <div className="relative w-24 h-24 mx-auto mb-3">
              <svg viewBox="0 0 36 36" className="w-24 h-24 -rotate-90">
                <circle cx="18" cy="18" r="15.9" fill="none" stroke="#1e293b" strokeWidth="3"/>
                <circle cx="18" cy="18" r="15.9" fill="none" stroke="#22c55e" strokeWidth="3"
                  strokeDasharray={`${health?.health_score||72} 100`} strokeLinecap="round"/>
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <span className="text-2xl font-bold text-white">{health?.health_score||72}</span>
              </div>
            </div>
            <p className="text-sm font-semibold text-green-400">{health?.status||"Bom"}</p>
            <div className="mt-4 space-y-2 text-left">
              <div className="flex justify-between text-xs">
                <span className="text-slate-400">Top 10</span>
                <span className="text-white font-medium">{health?.top_10||0} keywords</span>
              </div>
              <div className="flex justify-between text-xs">
                <span className="text-slate-400">Pos. Média</span>
                <span className="text-white font-medium">#{health?.avg_position||5}</span>
              </div>
            </div>
          </div>

          <button onClick={()=>auditMut.mutate()} disabled={auditMut.isPending}
            className="w-full py-3 bg-orange-500/20 border border-orange-500/30 text-orange-300 rounded-xl text-sm hover:bg-orange-500/30 transition-colors disabled:opacity-50">
            {auditMut.isPending?"🔍 Analisando...":"🔍 Rodar Auditoria IA"}
          </button>
        </div>
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-white mb-4">✨ Gerador de Conteúdo SEO (IA)</h3>
        <div className="flex gap-3 mb-4">
          <input type="text" placeholder="Ex: conserto celular São Paulo" value={keyword} onChange={e=>setKeyword(e.target.value)}
            className="flex-1 bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"/>
          <select value={contentType} onChange={e=>setContentType(e.target.value)}
            className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
            <option value="blog_post">Artigo Blog</option>
            <option value="meta_description">Meta Description</option>
            <option value="title">Títulos SEO</option>
          </select>
          <button onClick={()=>genMut.mutate()} disabled={!keyword||genMut.isPending}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white rounded-lg text-sm transition-colors">
            {genMut.isPending?"Gerando...":"Gerar"}
          </button>
        </div>
        {generated && (
          <div className="bg-slate-800 rounded-lg p-4 text-xs text-slate-200 max-h-60 overflow-y-auto whitespace-pre-wrap font-mono">
            {generated}
          </div>
        )}
      </div>
    </div>
  )
}