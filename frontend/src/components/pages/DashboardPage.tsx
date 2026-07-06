"use client"
import { useQuery } from "@tanstack/react-query"
import { getDashboardMetrics, getAgents, getReviews, getSEOKeywords } from "@/lib/api"
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from "recharts"

const COLORS = ["#3b82f6", "#22c55e", "#ec4899", "#f59e0b"]

export default function DashboardPage() {
  const { data: metrics } = useQuery({ queryKey: ["metrics"], queryFn: () => getDashboardMetrics().then(r => r.data) })
  const { data: agents } = useQuery({ queryKey: ["agents"], queryFn: () => getAgents().then(r => r.data) })
  const { data: reviews } = useQuery({ queryKey: ["reviews"], queryFn: () => getReviews().then(r => r.data) })
  const { data: keywords } = useQuery({ queryKey: ["keywords"], queryFn: () => getSEOKeywords().then(r => r.data) })

  const weekly = metrics?.weekly_data || []
  const pending = (reviews || []).filter((r: any) => !r.responded).length

  const cards = [
    { label: "Leads Orgânicos", value: metrics?.leads_organicos?.value || 147, change: "+23%", up: true, icon: "🎯" },
    { label: "Visitantes", value: (metrics?.visitantes_unicos?.value || 2847).toLocaleString(), change: "+18%", up: true, icon: "👥" },
    { label: "Avaliação Google", value: `${metrics?.avaliacao_google?.value || 4.8}⭐`, change: `${metrics?.avaliacao_google?.total || 0} avaliações`, up: true, icon: "⭐" },
    { label: "Ranking Médio", value: `#${metrics?.ranking_seo?.avg_position || 5}`, change: `${metrics?.ranking_seo?.top10 || 0} no Top10`, up: true, icon: "🔍" },
    { label: "Taxa Conversão", value: `${metrics?.taxa_conversao?.value || 14.2}%`, change: metrics?.taxa_conversao?.change || "", up: false, icon: "📊" },
    { label: "Engajamento", value: `${metrics?.engajamento_social?.value || 8.4}%`, change: "+1.2%", up: true, icon: "📱" },
  ]

  const traffic = [
    { name: "Google", value: 42 }, { name: "Maps", value: 28 },
    { name: "Social", value: 18 }, { name: "Direto", value: 12 },
  ]

  return (
    <div className="space-y-6">
      {pending > 0 && (
        <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-4 flex items-center gap-3">
          <span className="text-2xl">⚠️</span>
          <div>
            <p className="text-sm font-medium text-yellow-300">{pending} avaliações sem resposta no Google Maps</p>
            <p className="text-xs text-yellow-500">Responda rapidamente para melhorar seu ranking local</p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
        {cards.map((c, i) => (
          <div key={i} className="bg-slate-900 border border-slate-800 rounded-xl p-5 hover:border-slate-700 transition-all">
            <div className="flex items-center justify-between mb-3">
              <span className="text-2xl">{c.icon}</span>
              <span className={`text-xs font-medium px-2 py-1 rounded-full ${c.up ? "text-green-400 bg-green-400/10" : "text-red-400 bg-red-400/10"}`}>
                {c.up ? "↗" : "↘"} {c.change}
              </span>
            </div>
            <p className="text-2xl font-bold text-white mb-1">{c.value}</p>
            <p className="text-xs text-slate-400">{c.label}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-white mb-4">📈 Performance Semanal</h3>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={weekly}>
              <defs>
                <linearGradient id="gl" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/><stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="gc" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#22c55e" stopOpacity={0.3}/><stop offset="95%" stopColor="#22c55e" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <XAxis dataKey="day" tick={{fill:"#94a3b8",fontSize:12}} axisLine={false} tickLine={false}/>
              <YAxis tick={{fill:"#94a3b8",fontSize:12}} axisLine={false} tickLine={false}/>
              <Tooltip contentStyle={{backgroundColor:"#1e293b",border:"1px solid #334155",borderRadius:"8px"}}/>
              <Area type="monotone" dataKey="leads" stroke="#3b82f6" strokeWidth={2} fill="url(#gl)" name="Leads"/>
              <Area type="monotone" dataKey="conversao" stroke="#22c55e" strokeWidth={2} fill="url(#gc)" name="Conversões"/>
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-white mb-4">🌐 Fontes de Tráfego</h3>
          <div className="flex justify-center mb-4">
            <ResponsiveContainer width={150} height={150}>
              <PieChart>
                <Pie data={traffic} cx="50%" cy="50%" innerRadius={40} outerRadius={65} paddingAngle={3} dataKey="value">
                  {traffic.map((_, i) => <Cell key={i} fill={COLORS[i]}/>)}
                </Pie>
                <Tooltip contentStyle={{backgroundColor:"#1e293b",border:"1px solid #334155",borderRadius:"8px",fontSize:"12px"}}/>
              </PieChart>
            </ResponsiveContainer>
          </div>
          {traffic.map((t, i) => (
            <div key={t.name} className="flex items-center justify-between text-sm mb-2">
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full" style={{backgroundColor: COLORS[i]}}/>
                <span className="text-slate-400">{t.name}</span>
              </div>
              <span className="text-white font-medium">{t.value}%</span>
            </div>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-white mb-4">🤖 Agentes Ativos</h3>
          <div className="space-y-2">
            {(agents || []).map((a: any) => (
              <div key={a.id} className="flex items-center gap-3 p-2 rounded-lg hover:bg-slate-800/50">
                <span className="text-xl">{a.avatar}</span>
                <div className="flex-1">
                  <p className="text-xs font-medium text-white">{a.name}</p>
                  <p className="text-xs text-slate-500">{a.role}</p>
                </div>
                <div className={`w-2 h-2 rounded-full ${a.is_active ? "bg-green-400" : "bg-slate-600"}`}/>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-white mb-4">🔍 Top Keywords</h3>
          <div className="space-y-3">
            {(keywords || []).slice(0, 6).map((k: any, i: number) => (
              <div key={k.id} className="flex items-center gap-2">
                <span className="text-xs text-slate-500 w-4">{i+1}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-xs text-white truncate">{k.keyword}</p>
                  <div className="flex items-center gap-2 mt-0.5">
                    <div className="flex-1 h-1 bg-slate-800 rounded-full">
                      <div className="h-full bg-blue-400 rounded-full" style={{width: `${Math.max(5, 100-k.position*7)}%`}}/>
                    </div>
                    <span className="text-xs text-slate-400">#{k.position}</span>
                  </div>
                </div>
                <span className={`text-xs ${k.trend==="up"?"text-green-400":k.trend==="down"?"text-red-400":"text-slate-500"}`}>
                  {k.trend==="up"?"↗":k.trend==="down"?"↘":"→"}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-white mb-4">⭐ Avaliações Recentes</h3>
          <div className="space-y-3">
            {(reviews || []).slice(0,3).map((r: any) => (
              <div key={r.id} className="p-3 bg-slate-800/50 rounded-lg">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-xs font-medium text-white">{r.author}</span>
                  <div className="flex">{Array.from({length:r.rating}).map((_,i)=><span key={i} className="text-yellow-400 text-xs">★</span>)}</div>
                </div>
                <p className="text-xs text-slate-400 line-clamp-2">{r.content}</p>
                {!r.responded && <p className="text-xs text-orange-400 mt-1">• Aguardando resposta</p>}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}