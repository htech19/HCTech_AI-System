"use client"
import { useState } from "react"
import { useQuery, useMutation } from "@tanstack/react-query"
import { getSocialMetrics, generateSocialPost } from "@/lib/api"
import toast from "react-hot-toast"

export default function SocialPage() {
  const [platform, setPlatform] = useState("instagram")
  const [topic, setTopic] = useState("")
  const [generated, setGenerated] = useState<any>(null)

  const { data: metrics } = useQuery({ queryKey:["social-metrics"], queryFn:()=>getSocialMetrics().then(r=>r.data) })
  const genMut = useMutation({
    mutationFn:()=>generateSocialPost({platform,topic}).then(r=>r.data),
    onSuccess:(data)=>{setGenerated(data);toast.success("Post gerado!")}
  })

  const fb = metrics?.facebook
  const ig = metrics?.instagram

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-blue-600/20 flex items-center justify-center text-2xl">📘</div>
            <div><h3 className="text-sm font-semibold text-white">Facebook</h3><p className="text-xs text-slate-400">Página comercial</p></div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            {[["Seguidores",fb?.followers?.toLocaleString()],[" Alcance/sem",fb?.reach_week?.toLocaleString()],["Engajamento",`${fb?.engagement_rate}%`],["Mensagens",fb?.messages_pending+" pendentes"]].map(([l,v])=>(
              <div key={l} className="bg-slate-800/50 rounded-lg p-3">
                <p className="text-xs text-slate-400">{l}</p>
                <p className="text-sm font-bold text-white">{v}</p>
              </div>
            ))}
          </div>
        </div>
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-pink-600/20 flex items-center justify-center text-2xl">📸</div>
            <div><h3 className="text-sm font-semibold text-white">Instagram</h3><p className="text-xs text-slate-400">Perfil comercial</p></div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            {[["Seguidores",ig?.followers?.toLocaleString()],["Alcance/sem",ig?.reach_week?.toLocaleString()],["Engajamento",`${ig?.engagement_rate}%`],["Stories/sem",ig?.stories_week]].map(([l,v])=>(
              <div key={l} className="bg-slate-800/50 rounded-lg p-3">
                <p className="text-xs text-slate-400">{l}</p>
                <p className="text-sm font-bold text-white">{v}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-white mb-4">✨ Gerador de Posts (IA)</h3>
        <div className="flex gap-3 mb-4">
          <select value={platform} onChange={e=>setPlatform(e.target.value)}
            className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
            <option value="instagram">📸 Instagram</option>
            <option value="facebook">📘 Facebook</option>
          </select>
          <input type="text" placeholder="Tópico do post (ex: troca de tela iPhone)..." value={topic} onChange={e=>setTopic(e.target.value)}
            className="flex-1 bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"/>
          <button onClick={()=>genMut.mutate()} disabled={!topic||genMut.isPending}
            className="px-4 py-2 bg-pink-600 hover:bg-pink-500 disabled:opacity-50 text-white rounded-lg text-sm transition-colors">
            {genMut.isPending?"Gerando...":"✨ Gerar"}
          </button>
        </div>
        {generated && (
          <div className="space-y-3">
            <div className="bg-slate-800 rounded-lg p-4">
              <p className="text-xs text-slate-400 mb-2">📝 Caption:</p>
              <p className="text-sm text-white whitespace-pre-wrap">{generated.caption}</p>
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div className="bg-slate-800 rounded-lg p-3">
                <p className="text-xs text-slate-400 mb-1">#️⃣ Hashtags</p>
                <p className="text-xs text-blue-400">{(generated.hashtags||[]).join(" ")}</p>
              </div>
              <div className="bg-slate-800 rounded-lg p-3">
                <p className="text-xs text-slate-400 mb-1">📣 CTA</p>
                <p className="text-xs text-white">{generated.cta}</p>
              </div>
              <div className="bg-slate-800 rounded-lg p-3">
                <p className="text-xs text-slate-400 mb-1">⏰ Melhor Hora</p>
                <p className="text-xs text-green-400 font-bold">{generated.best_time}</p>
              </div>
            </div>
          </div>
        )}
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-white mb-4">⏰ Melhores Horários de Publicação</h3>
        <div className="grid grid-cols-2 gap-4">
          {["facebook","instagram"].map(p=>(
            <div key={p} className="bg-slate-800/50 rounded-lg p-4">
              <p className="text-xs font-medium text-slate-300 mb-3 capitalize">{p==="facebook"?"📘 Facebook":"📸 Instagram"}</p>
              <div className="flex gap-2">
                {(metrics?.best_times?.[p]||["19:00","12:00","09:00"]).map((t:string)=>(
                  <span key={t} className="bg-slate-700 text-white text-xs px-2 py-1 rounded font-mono">{t}</span>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}