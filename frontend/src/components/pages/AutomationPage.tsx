"use client"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getAutomationJobs, toggleJob, runJobNow } from "@/lib/api"
import toast from "react-hot-toast"

const cronLabels: Record<string,string> = {
  "0 9 * * *":"Diário às 09:00","0 8 * * 0":"Domingo às 08:00","0 2 * * *":"Diário às 02:00"
}

export default function AutomationPage() {
  const qc = useQueryClient()
  const { data: jobs = [] } = useQuery({ queryKey:["jobs"], queryFn:()=>getAutomationJobs().then(r=>r.data) })
  const toggleMut = useMutation({
    mutationFn:({id,active}:{id:number,active:boolean})=>toggleJob(id,active).then(r=>r.data),
    onSuccess:()=>{qc.invalidateQueries({queryKey:["jobs"]});toast.success("Job atualizado")}
  })
  const runMut = useMutation({
    mutationFn:(id:number)=>runJobNow(id).then(r=>r.data),
    onSuccess:(data)=>toast.success(data.message||"Executado!")
  })

  const typeIcons: Record<string,string> = { review_check:"⭐", seo_report:"🔍", backup:"💾", social_post:"📱" }

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-3 gap-4">
        {[
          {label:"Jobs Ativos",value:(jobs as any[]).filter((j:any)=>j.is_active).length,color:"text-green-400"},
          {label:"Total Execuções",value:(jobs as any[]).reduce((a:number,j:any)=>a+j.run_count,0),color:"text-blue-400"},
          {label:"Taxa de Sucesso",value:`${Math.round(((jobs as any[]).reduce((a:number,j:any)=>a+j.success_count,0)/Math.max(1,(jobs as any[]).reduce((a:number,j:any)=>a+j.run_count,0)))*100)}%`,color:"text-purple-400"},
        ].map((s,i)=>(
          <div key={i} className="bg-slate-900 border border-slate-800 rounded-xl p-5">
            <p className="text-xs text-slate-400">{s.label}</p>
            <p className={`text-2xl font-bold mt-1 ${s.color}`}>{s.value}</p>
          </div>
        ))}
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div className="p-4 border-b border-slate-800">
          <h3 className="text-sm font-semibold text-white">⚙️ Jobs de Automação</h3>
        </div>
        <div className="divide-y divide-slate-800">
          {(jobs as any[]).map((j:any)=>(
            <div key={j.id} className="flex items-center gap-4 p-4 hover:bg-slate-800/30 transition-colors">
              <span className="text-2xl flex-shrink-0">{typeIcons[j.job_type]||"⚙️"}</span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-white">{j.name}</p>
                <p className="text-xs text-slate-400">{j.description}</p>
                <div className="flex items-center gap-3 mt-1">
                  <span className="text-xs text-slate-500 font-mono">{cronLabels[j.schedule]||j.schedule}</span>
                  <span className="text-xs text-slate-600">• {j.run_count} execuções</span>
                  {j.last_run && <span className="text-xs text-slate-600">• Último: {new Date(j.last_run).toLocaleDateString("pt-BR")}</span>}
                </div>
              </div>
              <div className="flex items-center gap-2 flex-shrink-0">
                <button onClick={()=>runMut.mutate(j.id)} disabled={runMut.isPending}
                  className="text-xs text-blue-400 border border-blue-400/30 px-2 py-1 rounded hover:bg-blue-400/10 transition-colors disabled:opacity-50">
                  ▶ Executar
                </button>
                <button onClick={()=>toggleMut.mutate({id:j.id,active:!j.is_active})}
                  className={`relative w-10 h-5 rounded-full transition-colors ${j.is_active?"bg-green-500":"bg-slate-700"}`}>
                  <div className={`absolute top-0.5 w-4 h-4 bg-white rounded-full transition-transform ${j.is_active?"translate-x-5":"translate-x-0.5"}`}/>
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}