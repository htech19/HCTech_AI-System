"use client"
import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getTasks, createTask, deleteTask, moveTask } from "@/lib/api"
import toast from "react-hot-toast"

const cols = [
  { id: "todo", label: "📋 A Fazer", color: "border-yellow-500/30 bg-yellow-500/5", badge: "bg-yellow-500/20 text-yellow-300" },
  { id: "in_progress", label: "⚡ Em Progresso", color: "border-blue-500/30 bg-blue-500/5", badge: "bg-blue-500/20 text-blue-300" },
  { id: "done", label: "✅ Concluído", color: "border-green-500/30 bg-green-500/5", badge: "bg-green-500/20 text-green-300" },
]
const prioColors: Record<string, string> = {
  low: "bg-slate-700 text-slate-300", medium: "bg-blue-500/20 text-blue-300",
  high: "bg-orange-500/20 text-orange-300", urgent: "bg-red-500/20 text-red-300",
}
const avatars: Record<string, string> = {
  "hc-ceo":"👔","hc-seo":"🔍","hc-social":"📱","hc-content":"✍️","hc-code":"💻"
}

export default function KanbanPage() {
  const qc = useQueryClient()
  const [modal, setModal] = useState<string|null>(null)
  const [form, setForm] = useState({ title:"", desc:"", priority:"medium", agent:"" })

  const { data: tasks = [] } = useQuery({ queryKey:["tasks"], queryFn:()=>getTasks().then(r=>r.data) })
  const moveMut = useMutation({ mutationFn:({id,st}:{id:number,st:string})=>moveTask(id,st), onSuccess:()=>qc.invalidateQueries({queryKey:["tasks"]}) })
  const delMut = useMutation({ mutationFn:deleteTask, onSuccess:()=>{qc.invalidateQueries({queryKey:["tasks"]});toast.success("Removida")} })
  const createMut = useMutation({
    mutationFn: createTask,
    onSuccess:()=>{qc.invalidateQueries({queryKey:["tasks"]});setModal(null);setForm({title:"",desc:"",priority:"medium",agent:""});toast.success("Tarefa criada!")}
  })

  const byStatus = (st: string) => (tasks as any[]).filter((t:any)=>t.status===st)

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-white">Workflow Kanban</h2>
          <p className="text-xs text-slate-400">{(tasks as any[]).length} tarefas total</p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4">
        {cols.map(col => {
          const colTasks = byStatus(col.id)
          return (
            <div key={col.id} className={`bg-slate-900 border rounded-xl overflow-hidden ${col.color}`}>
              <div className="flex items-center justify-between p-4 border-b border-slate-800">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-semibold text-white">{col.label}</span>
                  <span className={`text-xs px-1.5 py-0.5 rounded-full font-medium ${col.badge}`}>{colTasks.length}</span>
                </div>
                <button onClick={()=>setModal(col.id)} className="w-6 h-6 rounded bg-slate-800 text-slate-400 hover:text-white flex items-center justify-center text-lg leading-none">+</button>
              </div>
              <div className="p-3 space-y-2 min-h-[200px]">
                {colTasks.map((t:any) => (
                  <div key={t.id} className="bg-slate-800 border border-slate-700 rounded-lg p-3 group hover:border-slate-600">
                    <div className="flex items-start justify-between gap-2 mb-2">
                      <p className="text-xs text-white font-medium flex-1">{t.title}</p>
                      <button onClick={()=>delMut.mutate(t.id)} className="opacity-0 group-hover:opacity-100 text-slate-500 hover:text-red-400 text-xs">✕</button>
                    </div>
                    {t.description && <p className="text-xs text-slate-500 mb-2 line-clamp-2">{t.description}</p>}
                    <div className="flex items-center gap-1 flex-wrap mb-2">
                      <span className={`text-xs px-1.5 py-0.5 rounded ${prioColors[t.priority]||prioColors.medium}`}>{t.priority}</span>
                      {t.agent_id && <span className="text-xs">{avatars[t.agent_id]||"🤖"}</span>}
                      {(t.tags||[]).map((tag:string)=>(
                        <span key={tag} className="text-xs bg-slate-700 text-slate-400 px-1.5 py-0.5 rounded">{tag}</span>
                      ))}
                    </div>
                    <div className="flex gap-1">
                      {cols.filter(c=>c.id!==col.id).map(target=>(
                        <button key={target.id} onClick={()=>moveMut.mutate({id:t.id,st:target.id})}
                          className={`flex-1 text-xs py-1 rounded border ${target.color} text-slate-300 hover:text-white transition-colors`}>
                          → {target.label.split(" ").slice(1).join(" ")}
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
                {colTasks.length===0 && <p className="text-xs text-slate-700 text-center py-8">Nenhuma tarefa</p>}
              </div>
            </div>
          )
        })}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" onClick={()=>setModal(null)}>
          <div className="bg-slate-900 border border-slate-700 rounded-2xl p-6 w-full max-w-md shadow-2xl" onClick={e=>e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-base font-semibold text-white">Nova Tarefa</h3>
              <button onClick={()=>setModal(null)} className="text-slate-400 hover:text-white">✕</button>
            </div>
            <div className="space-y-3">
              <input type="text" placeholder="Título..." value={form.title} onChange={e=>setForm({...form,title:e.target.value})}
                autoFocus className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"/>
              <textarea placeholder="Descrição (opcional)..." value={form.desc} onChange={e=>setForm({...form,desc:e.target.value})}
                className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 resize-none h-16"/>
              <div className="grid grid-cols-2 gap-2">
                <select value={form.priority} onChange={e=>setForm({...form,priority:e.target.value})}
                  className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
                  <option value="low">Baixa</option><option value="medium">Média</option>
                  <option value="high">Alta</option><option value="urgent">Urgente</option>
                </select>
                <select value={form.agent} onChange={e=>setForm({...form,agent:e.target.value})}
                  className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
                  <option value="">Sem agente</option>
                  <option value="hc-ceo">👔 CEO</option><option value="hc-seo">🔍 SEO</option>
                  <option value="hc-social">📱 Social</option><option value="hc-content">✍️ Content</option>
                  <option value="hc-code">💻 Code</option>
                </select>
              </div>
              <div className="flex gap-2 pt-2">
                <button onClick={()=>setModal(null)} className="flex-1 py-2 text-sm text-slate-400 border border-slate-700 rounded-lg hover:bg-slate-800">Cancelar</button>
                <button onClick={()=>createMut.mutate({title:form.title,description:form.desc,status:modal,priority:form.priority,agent_id:form.agent||undefined,tags:[]})}
                  disabled={!form.title.trim()||createMut.isPending}
                  className="flex-1 py-2 text-sm text-white bg-blue-600 hover:bg-blue-500 disabled:opacity-50 rounded-lg transition-colors">
                  {createMut.isPending?"Criando...":"✓ Criar"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}