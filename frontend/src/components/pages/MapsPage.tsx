"use client"
import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getReviews, getMapsProfile, autoRespondReview } from "@/lib/api"
import toast from "react-hot-toast"

export default function MapsPage() {
  const qc = useQueryClient()
  const { data: reviews = [] } = useQuery({ queryKey:["reviews"], queryFn:()=>getReviews().then(r=>r.data) })
  const { data: profile } = useQuery({ queryKey:["maps-profile"], queryFn:()=>getMapsProfile().then(r=>r.data) })

  const respondMut = useMutation({
    mutationFn:(id:number)=>autoRespondReview(id).then(r=>r.data),
    onSuccess:()=>{qc.invalidateQueries({queryKey:["reviews"]});toast.success("Resposta gerada pela IA!")}
  })

  const sentColor = (s:string) => s==="positive"?"text-green-400 bg-green-400/10":s==="negative"?"text-red-400 bg-red-400/10":"text-yellow-400 bg-yellow-400/10"

  return (
    <div className="space-y-6">
      {profile && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            {label:"Avaliação",value:`${profile.rating}⭐`,sub:`${profile.total_reviews} avaliações`},
            {label:"Taxa Resposta",value:profile.response_rate,sub:`${profile.responded_reviews} respondidas`},
            {label:"Visualizações/mês",value:profile.monthly_views?.toLocaleString(),sub:"Perfil visto"},
            {label:"Completude",value:`${profile.profile_completeness}%`,sub:profile.status},
          ].map((c,i)=>(
            <div key={i} className="bg-slate-900 border border-slate-800 rounded-xl p-5">
              <p className="text-xs text-slate-400 mb-1">{c.label}</p>
              <p className="text-xl font-bold text-white">{c.value}</p>
              <p className="text-xs text-slate-500 mt-1">{c.sub}</p>
            </div>
          ))}
        </div>
      )}

      <div className="grid grid-cols-3 gap-4">
        {[
          {label:"Cliques Ligação",value:profile?.calls||89,icon:"📞",color:"text-green-400"},
          {label:"Pedidos Rota",value:profile?.directions||156,icon:"🗺️",color:"text-blue-400"},
          {label:"Cliques Site",value:234,icon:"🌐",color:"text-purple-400"},
        ].map((s,i)=>(
          <div key={i} className="bg-slate-900 border border-slate-800 rounded-xl p-4 flex items-center gap-4">
            <span className="text-3xl">{s.icon}</span>
            <div>
              <p className={`text-xl font-bold ${s.color}`}>{s.value}</p>
              <p className="text-xs text-slate-400">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-semibold text-white">⭐ Avaliações Google Maps</h3>
          <span className="text-xs text-slate-400">{(reviews as any[]).filter((r:any)=>!r.responded).length} sem resposta</span>
        </div>
        <div className="space-y-4">
          {(reviews as any[]).map((r:any)=>(
            <div key={r.id} className="bg-slate-800/50 border border-slate-700 rounded-xl p-4">
              <div className="flex items-start justify-between gap-3 mb-3">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-sm font-medium text-white">{r.author}</span>
                    <div className="flex">{Array.from({length:r.rating}).map((_,i)=><span key={i} className="text-yellow-400 text-xs">★</span>)}</div>
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${sentColor(r.sentiment)}`}>{r.sentiment}</span>
                  </div>
                  <p className="text-sm text-slate-300">{r.content}</p>
                </div>
                {!r.responded && (
                  <button onClick={()=>respondMut.mutate(r.id)} disabled={respondMut.isPending}
                    className="flex-shrink-0 text-xs px-3 py-1.5 bg-blue-600/20 border border-blue-500/30 text-blue-300 rounded-lg hover:bg-blue-600/30 transition-colors disabled:opacity-50">
                    {respondMut.isPending?"🤖...":"🤖 IA"}
                  </button>
                )}
              </div>
              {r.ai_response && (
                <div className="bg-slate-900 rounded-lg p-3 border-l-2 border-blue-500">
                  <p className="text-xs text-slate-400 mb-1">✅ Resposta:</p>
                  <p className="text-xs text-slate-300">{r.ai_response}</p>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}