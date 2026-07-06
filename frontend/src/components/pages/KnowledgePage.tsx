"use client"
import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getKnowledge, createArticle, deleteArticle } from "@/lib/api"
import toast from "react-hot-toast"
import ReactMarkdown from "react-markdown"

export default function KnowledgePage() {
  const qc = useQueryClient()
  const [search, setSearch] = useState("")
  const [selected, setSelected] = useState<any>(null)
  const [creating, setCreating] = useState(false)
  const [form, setForm] = useState({ title:"", content:"", category:"Geral" })

  const { data: articles = [] } = useQuery({ queryKey:["knowledge",search], queryFn:()=>getKnowledge(search||undefined).then(r=>r.data) })
  const createMut = useMutation({
    mutationFn:()=>createArticle(form).then(r=>r.data),
    onSuccess:()=>{qc.invalidateQueries({queryKey:["knowledge"]});setCreating(false);setForm({title:"",content:"",category:"Geral"});toast.success("Artigo criado!")}
  })
  const delMut = useMutation({
    mutationFn:(id:number)=>deleteArticle(id),
    onSuccess:()=>{qc.invalidateQueries({queryKey:["knowledge"]});setSelected(null);toast.success("Removido")}
  })

  return (
    <div className="flex gap-4 h-[calc(100vh-8rem)]">
      <div className="w-72 flex-shrink-0 flex flex-col bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div className="p-4 border-b border-slate-800 space-y-2">
          <input type="text" placeholder="🔍 Buscar artigos..." value={search} onChange={e=>setSearch(e.target.value)}
            className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"/>
          <button onClick={()=>setCreating(true)} className="w-full py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-xs transition-colors">+ Novo Artigo</button>
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-1">
          {(articles as any[]).map((a:any)=>(
            <button key={a.id} onClick={()=>setSelected(a)}
              className={`w-full text-left p-3 rounded-lg transition-colors ${selected?.id===a.id?"bg-slate-700 border border-slate-600":"hover:bg-slate-800/50 border border-transparent"}`}>
              <p className="text-xs font-medium text-white truncate">{a.title}</p>
              <div className="flex items-center gap-2 mt-1">
                <span className="text-xs text-slate-500 bg-slate-800 px-1.5 py-0.5 rounded">{a.category}</span>
                <span className="text-xs text-slate-600">{a.view_count} views</span>
              </div>
            </button>
          ))}
          {(articles as any[]).length===0 && <p className="text-xs text-slate-600 text-center py-8">Nenhum artigo encontrado</p>}
        </div>
      </div>

      <div className="flex-1 bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        {creating ? (
          <div className="p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-semibold text-white">Novo Artigo</h3>
              <button onClick={()=>setCreating(false)} className="text-slate-400 hover:text-white">✕</button>
            </div>
            <input type="text" placeholder="Título do artigo..." value={form.title} onChange={e=>setForm({...form,title:e.target.value})}
              className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500"/>
            <select value={form.category} onChange={e=>setForm({...form,category:e.target.value})}
              className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
              <option>Geral</option><option>Processos</option><option>SEO</option>
              <option>Social Media</option><option>Técnico</option><option>Atendimento</option>
            </select>
            <textarea placeholder="Conteúdo (suporta Markdown)..." value={form.content} onChange={e=>setForm({...form,content:e.target.value})}
              className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500 resize-none h-64 font-mono"/>
            <div className="flex gap-2">
              <button onClick={()=>setCreating(false)} className="flex-1 py-2 text-sm text-slate-400 border border-slate-700 rounded-lg hover:bg-slate-800">Cancelar</button>
              <button onClick={()=>createMut.mutate()} disabled={!form.title||!form.content||createMut.isPending}
                className="flex-1 py-2 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white rounded-lg text-sm">
                {createMut.isPending?"Salvando...":"💾 Salvar"}
              </button>
            </div>
          </div>
        ) : selected ? (
          <div className="p-6 h-full overflow-y-auto">
            <div className="flex items-start justify-between mb-4">
              <div>
                <h2 className="text-base font-bold text-white">{selected.title}</h2>
                <p className="text-xs text-slate-400 mt-1">{selected.category} • {selected.view_count} visualizações</p>
              </div>
              <button onClick={()=>delMut.mutate(selected.id)} className="text-xs text-red-400 hover:text-red-300 border border-red-400/30 px-2 py-1 rounded-lg">🗑️ Remover</button>
            </div>
            <div className="prose prose-invert prose-sm max-w-none">
              <ReactMarkdown>{selected.content}</ReactMarkdown>
            </div>
          </div>
        ) : (
          <div className="flex items-center justify-center h-full">
            <div className="text-center">
              <span className="text-4xl">📚</span>
              <p className="text-sm text-slate-400 mt-3">Selecione um artigo para visualizar</p>
              <p className="text-xs text-slate-600 mt-1">ou crie um novo</p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}