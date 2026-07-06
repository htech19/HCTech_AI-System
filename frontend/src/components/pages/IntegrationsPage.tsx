"use client"
import { useState, useEffect } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { motion, AnimatePresence } from "framer-motion"
import toast from "react-hot-toast"
import { api } from "@/lib/api"

interface Integration {
  id: number
  platform: string
  name: string
  status: "connected" | "disconnected" | "error" | "token_expired"
  account_name?: string
  account_email?: string
  avatar_url?: string
  permissions: string[]
  connected_at?: string
  last_sync?: string
  token_valid: boolean
  meta_data?: Record<string, any>
}

interface PlatformCfg {
  id: string
  name: string
  description: string
  icon: string
  color: string
  bg: string
  border: string
  badge: string
  features: string[]
  tokenGuide: string
  tokenUrl: string
  envVars: string[]
  steps: string[]
}

const PLATFORMS: PlatformCfg[] = [
  {
    id: "facebook", name: "Facebook", icon: "📘",
    description: "Paginas, posts e metricas de engajamento",
    color: "text-blue-400", bg: "bg-blue-500/10",
    border: "border-blue-500/30", badge: "bg-blue-500/20 text-blue-300",
    features: ["Posts automaticos", "Metricas", "Mensagens", "Insights"],
    tokenGuide: "Meta for Developers → Explorador de API do Graph → Gerar Token",
    tokenUrl: "https://developers.facebook.com/tools/explorer/",
    envVars: ["FACEBOOK_APP_ID", "FACEBOOK_APP_SECRET"],
    steps: [
      "Acesse developers.facebook.com e faca login",
      "Crie um App → Tipo: Business",
      "Va em Ferramentas → Explorador de API do Graph",
      "Selecione seu App e clique em Gerar Token de Acesso",
      "Marque: pages_show_list, pages_read_engagement",
      "Copie o token e cole no campo abaixo",
    ],
  },
  {
    id: "instagram", name: "Instagram Business", icon: "📸",
    description: "Posts, stories, reels e analytics",
    color: "text-pink-400", bg: "bg-pink-500/10",
    border: "border-pink-500/30", badge: "bg-pink-500/20 text-pink-300",
    features: ["Posts e Stories", "Reels", "Hashtags", "Analytics"],
    tokenGuide: "Usa o mesmo token do Facebook (Graph API). Precisa conta Business.",
    tokenUrl: "https://developers.facebook.com/tools/explorer/",
    envVars: ["FACEBOOK_APP_ID", "FACEBOOK_APP_SECRET"],
    steps: [
      "Vincule sua conta Instagram a uma Pagina do Facebook",
      "Acesse developers.facebook.com",
      "No Explorador de API, adicione permissao: instagram_basic",
      "Adicione: instagram_content_publish para publicar",
      "Gere o token e cole abaixo",
    ],
  },
  {
    id: "google", name: "Google Meu Negocio", icon: "🏢",
    description: "Perfil, avaliacoes e insights locais",
    color: "text-green-400", bg: "bg-green-500/10",
    border: "border-green-500/30", badge: "bg-green-500/20 text-green-300",
    features: ["Perfil do negocio", "Avaliacoes", "Posts", "Insights"],
    tokenGuide: "Google Cloud Console → APIs → Business Profile → Credenciais OAuth 2.0",
    tokenUrl: "https://console.cloud.google.com/",
    envVars: ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET"],
    steps: [
      "Acesse console.cloud.google.com",
      "Crie um projeto novo",
      "Va em APIs e Servicos → Ativar APIs",
      "Ative: Business Profile API",
      "Crie credenciais: OAuth 2.0 → App da Web",
      "Adicione URI de redirecionamento: http://localhost:8000/api/integrations/google/callback",
      "Copie Client ID e Secret para o .env",
      "Use o botao OAuth para autorizar",
    ],
  },
  {
    id: "maps", name: "Google Maps", icon: "🗺️",
    description: "Localizacao, rotas e visibilidade no Maps",
    color: "text-red-400", bg: "bg-red-500/10",
    border: "border-red-500/30", badge: "bg-red-500/20 text-red-300",
    features: ["Posicao no Maps", "Rotas", "Fotos", "Q&A"],
    tokenGuide: "Google Cloud Console → APIs → Maps → Criar chave de API",
    tokenUrl: "https://console.cloud.google.com/google/maps-apis/",
    envVars: ["GOOGLE_MAPS_API_KEY"],
    steps: [
      "Acesse console.cloud.google.com",
      "APIs e Servicos → Ativar APIs",
      "Ative: Maps JavaScript API e Places API",
      "Credenciais → Criar Chave de API",
      "Copie a chave e adicione no .env como GOOGLE_MAPS_API_KEY",
      "Para conectar aqui, use o token OAuth do Google Meu Negocio",
    ],
  },
  {
    id: "mercadolivre", name: "Mercado Livre", icon: "🛒",
    description: "Anuncios, vendas e reputacao de vendedor",
    color: "text-yellow-400", bg: "bg-yellow-500/10",
    border: "border-yellow-500/30", badge: "bg-yellow-500/20 text-yellow-300",
    features: ["Anuncios", "Vendas", "Reputacao", "Mensagens"],
    tokenGuide: "Mercado Livre Developers → Criar App → Credenciais",
    tokenUrl: "https://developers.mercadolivre.com.br/",
    envVars: ["ML_CLIENT_ID", "ML_CLIENT_SECRET"],
    steps: [
      "Acesse developers.mercadolivre.com.br",
      "Faca login com sua conta do Mercado Livre",
      "Clique em Criar aplicativo",
      "Preencha os dados e salve",
      "Copie Client ID e Secret para o .env",
      "Adicione a URI: http://localhost:8000/api/integrations/mercadolivre/callback",
      "Use o botao OAuth para conectar",
    ],
  },
]

const getIntegrations = () => api.get("/integrations").then(r => r.data as Integration[])
const getLogs        = () => api.get("/integrations/logs").then(r => r.data)
const getOAuthUrl    = (p: string) => api.get(`/integrations/${p}/oauth-url`).then(r => r.data)

function StatusDot({ status }: { status: string }) {
  const c = status === "connected" ? "bg-green-400 shadow-green-400/50"
          : status === "token_expired" ? "bg-orange-400"
          : status === "error" ? "bg-red-400"
          : "bg-slate-600"
  return <span className={`inline-block w-2 h-2 rounded-full ${c} ${status==="connected"?"shadow-sm animate-pulse":""}`} />
}

function StatusBadge({ status }: { status: string }) {
  const cfg = {
    connected:     { label: "Conectado",    cls: "bg-green-500/20 text-green-400 border-green-500/30" },
    disconnected:  { label: "Desconectado", cls: "bg-slate-700 text-slate-400 border-slate-600" },
    error:         { label: "Erro",         cls: "bg-red-500/20 text-red-400 border-red-500/30" },
    token_expired: { label: "Expirado",     cls: "bg-orange-500/20 text-orange-400 border-orange-500/30" },
  }
  const s = cfg[status as keyof typeof cfg] || cfg.disconnected
  return <span className={`text-xs px-2 py-0.5 rounded-full border font-medium ${s.cls}`}>{s.label}</span>
}

function Modal({ children, onClose, wide = false }: {
  children: React.ReactNode; onClose: () => void; wide?: boolean
}) {
  return (
    <motion.div initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}}
      className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      onClick={onClose}>
      <motion.div initial={{opacity:0,scale:0.95,y:20}} animate={{opacity:1,scale:1,y:0}}
        exit={{opacity:0,scale:0.95}}
        className={`bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden max-h-[90vh] overflow-y-auto ${wide?"w-full max-w-2xl":"w-full max-w-md"}`}
        onClick={e=>e.stopPropagation()}>
        {children}
      </motion.div>
    </motion.div>
  )
}

export default function IntegrationsPage() {
  const qc = useQueryClient()
  const [modal, setModal] = useState<{type:"config"|"guide"|"details"; platform: PlatformCfg}|null>(null)
  const [token, setToken] = useState("")
  const [showToken, setShowToken] = useState(false)
  const [tab, setTab] = useState<"grid"|"logs">("grid")

  const { data: integrations = [], isLoading } = useQuery({
    queryKey: ["integrations"],
    queryFn: getIntegrations,
    refetchInterval: 30000,
  })
  const { data: logs = [] } = useQuery({
    queryKey: ["int-logs"],
    queryFn: getLogs,
    enabled: tab === "logs",
    refetchInterval: 10000,
  })

  useEffect(() => {
    const fn = (e: MessageEvent) => {
      if (e.data?.type === "success") {
        toast.success(`✅ ${e.data.platform} conectado!`)
        qc.invalidateQueries({ queryKey: ["integrations"] })
        setModal(null)
      } else if (e.data?.type === "error") {
        toast.error(`Erro: ${e.data.message || "Falha na conexao"}`)
      }
    }
    window.addEventListener("message", fn)
    return () => window.removeEventListener("message", fn)
  }, [qc])

  const disconnectMut = useMutation({
    mutationFn: (p: string) => api.delete(`/integrations/${p}/disconnect`).then(r => r.data),
    onSuccess: () => { qc.invalidateQueries({queryKey:["integrations"]}); toast.success("Desconectado"); setModal(null) },
  })
  const syncMut = useMutation({
    mutationFn: (p: string) => api.post(`/integrations/${p}/sync`).then(r => r.data),
    onSuccess: (_, p) => { qc.invalidateQueries({queryKey:["integrations"]}); toast.success(`${p} sincronizado!`) },
  })
  const configMut = useMutation({
    mutationFn: ({ p, t }: { p: string; t: string }) =>
      api.post(`/integrations/${p}/configure`, { access_token: t }).then(r => r.data),
    onSuccess: (d) => {
      qc.invalidateQueries({queryKey:["integrations"]})
      toast.success(d.message || "Conectado!")
      setModal(null); setToken("")
    },
    onError: (e: any) => toast.error(e.message || "Token invalido"),
  })

  const handleOAuth = async (p: PlatformCfg) => {
    try {
      const { oauth_url } = await getOAuthUrl(p.id)
      const popup = window.open(oauth_url, "oauth", "width=620,height=720,scrollbars=yes")
      if (!popup) toast.error("Popup bloqueado! Permita popups para este site.")
    } catch (e: any) {
      const d = e.response?.data?.detail
      if (typeof d === "object" && d?.error === "credentials_missing") {
        toast.error(`Configure ${d.env_vars?.join(" e ")} no .env`)
        setModal({ type: "guide", platform: p })
      } else {
        toast.error(e.message || "Erro ao gerar URL")
      }
    }
  }

  const getStatus = (id: string) => (integrations as Integration[]).find(i => i.platform === id)
  const connected = (integrations as Integration[]).filter(i => i.status === "connected").length

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-white">🔗 Integracoes</h2>
          <p className="text-xs text-slate-400">{connected}/{PLATFORMS.length} plataformas conectadas</p>
        </div>
        <div className="flex gap-2">
          {(["grid","logs"] as const).map(t => (
            <button key={t} onClick={() => setTab(t)}
              className={`px-4 py-2 rounded-lg text-xs font-medium transition-colors ${
                tab===t ? "bg-blue-600 text-white" : "bg-slate-800 text-slate-400 hover:text-white"}`}>
              {t === "grid" ? "🔌 Plataformas" : "📋 Logs"}
            </button>
          ))}
        </div>
      </div>

      {/* Status bar */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
        {PLATFORMS.map(p => {
          const s = getStatus(p.id)
          const ok = s?.status === "connected"
          return (
            <div key={p.id} className={`flex items-center gap-2 px-3 py-2 rounded-lg border text-xs ${ok ? `${p.bg} ${p.border}` : "bg-slate-900 border-slate-800"}`}>
              <span className="text-base">{p.icon}</span>
              <div className="min-w-0">
                <p className={`font-semibold truncate ${ok ? p.color : "text-slate-400"}`}>{p.name.split(" ")[0]}</p>
                <div className="flex items-center gap-1">
                  <StatusDot status={s?.status || "disconnected"} />
                  <span className={ok ? "text-green-400" : "text-slate-600"}>{ok ? "Online" : "Offline"}</span>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Content */}
      {tab === "grid" ? (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {PLATFORMS.map((p, i) => {
            const s = getStatus(p.id)
            const ok = s?.status === "connected"
            const exp = s?.status === "token_expired"
            return (
              <motion.div key={p.id} initial={{opacity:0,y:20}} animate={{opacity:1,y:0}} transition={{delay:i*0.05}}
                className={`bg-slate-900 rounded-xl border overflow-hidden hover:border-slate-600 transition-all ${ok ? p.border : "border-slate-800"}`}>

                {/* Top */}
                <div className={`p-4 flex items-start gap-3 ${ok ? p.bg : ""}`}>
                  <div className={`w-12 h-12 rounded-xl flex items-center justify-center text-2xl flex-shrink-0 ${p.bg} border ${p.border}`}>{p.icon}</div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap mb-0.5">
                      <h3 className="text-sm font-bold text-white">{p.name}</h3>
                      <StatusBadge status={s?.status || "disconnected"} />
                    </div>
                    <p className="text-xs text-slate-400">{p.description}</p>
                    {ok && s?.account_name && (
                      <div className="flex items-center gap-1.5 mt-1.5">
                        {s.avatar_url && (
                          <img src={s.avatar_url} alt="" className="w-4 h-4 rounded-full object-cover"
                            onError={e => { (e.target as HTMLImageElement).style.display = "none" }} />
                        )}
                        <span className={`text-xs font-medium ${p.color} truncate`}>{s.account_name}</span>
                      </div>
                    )}
                  </div>
                </div>

                {/* Features */}
                <div className="px-4 py-3 border-t border-slate-800">
                  <div className="flex flex-wrap gap-1 mb-3">
                    {p.features.map(f => (
                      <span key={f} className={`text-xs px-2 py-0.5 rounded-full border ${ok ? `${p.badge} ${p.border}` : "bg-slate-800 text-slate-600 border-slate-700"}`}>{f}</span>
                    ))}
                  </div>

                  {ok && s?.last_sync && (
                    <p className="text-xs text-slate-600 mb-3">
                      🔄 {new Date(s.last_sync).toLocaleString("pt-BR", {timeStyle:"short",dateStyle:"short"})}
                    </p>
                  )}

                  {/* Buttons */}
                  {ok ? (
                    <div className="flex gap-2">
                      <button onClick={() => setModal({type:"details", platform:p})}
                        className={`flex-1 py-2 text-xs font-medium rounded-lg border ${p.bg} ${p.color} ${p.border} hover:opacity-80 transition-opacity`}>
                        📊 Detalhes
                      </button>
                      <button onClick={() => syncMut.mutate(p.id)} disabled={syncMut.isPending}
                        className="px-3 py-2 text-xs text-slate-400 border border-slate-700 rounded-lg hover:bg-slate-800 transition-colors" title="Sincronizar">
                        🔄
                      </button>
                      <button onClick={() => { if(confirm(`Desconectar ${p.name}?`)) disconnectMut.mutate(p.id) }}
                        className="px-3 py-2 text-xs text-red-400 border border-red-500/30 rounded-lg hover:bg-red-500/10 transition-colors" title="Desconectar">
                        ✕
                      </button>
                    </div>
                  ) : (
                    <div className="space-y-2">
                      <div className="flex gap-2">
                        <button onClick={() => { setModal({type:"config", platform:p}); setToken("") }}
                          className={`flex-1 py-2 text-xs font-medium rounded-lg border ${p.bg} ${p.color} ${p.border} hover:opacity-80`}>
                          🔑 Token Manual
                        </button>
                        <button onClick={() => handleOAuth(p)}
                          className="flex-1 py-2 text-xs font-medium rounded-lg bg-slate-800 border border-slate-700 text-slate-300 hover:bg-slate-700 transition-colors">
                          🔐 OAuth
                        </button>
                      </div>
                      <button onClick={() => setModal({type:"guide", platform:p})}
                        className="w-full text-xs text-slate-600 hover:text-slate-400 py-1 transition-colors">
                        📖 Como obter credenciais →
                      </button>
                    </div>
                  )}
                  {exp && <p className="text-xs text-orange-400 mt-2 text-center">⚠️ Token expirado — reconecte</p>}
                </div>
              </motion.div>
            )
          })}
        </div>
      ) : (
        /* LOGS */
        <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
          <div className="p-4 border-b border-slate-800 flex items-center justify-between">
            <h3 className="text-sm font-semibold text-white">📋 Historico de Integracoes</h3>
            <button onClick={() => qc.invalidateQueries({queryKey:["int-logs"]})}
              className="text-xs text-slate-400 hover:text-white">🔄 Atualizar</button>
          </div>
          <div className="divide-y divide-slate-800 max-h-[500px] overflow-y-auto">
            {(logs as any[]).length === 0
              ? <p className="text-xs text-slate-600 text-center py-10">Nenhum log ainda</p>
              : (logs as any[]).map((l, i) => {
                  const pc = PLATFORMS.find(p => p.id === l.platform)
                  return (
                    <div key={i} className="flex items-center gap-3 p-3 hover:bg-slate-800/30 transition-colors">
                      <span className="text-xl flex-shrink-0">{pc?.icon || "🔌"}</span>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          <span className="text-xs font-medium text-white capitalize">{l.platform}</span>
                          <span className="text-xs text-slate-500">{l.action}</span>
                          <span className={`text-xs px-1.5 py-0.5 rounded ${l.status==="success"?"bg-green-500/20 text-green-400":"bg-red-500/20 text-red-400"}`}>
                            {l.status}
                          </span>
                        </div>
                        {l.message && <p className="text-xs text-slate-400 truncate">{l.message}</p>}
                      </div>
                      <span className="text-xs text-slate-600 flex-shrink-0">
                        {new Date(l.created_at).toLocaleString("pt-BR",{timeStyle:"short",dateStyle:"short"})}
                      </span>
                    </div>
                  )
                })}
          </div>
        </div>
      )}

      {/* MODAIS */}
      <AnimatePresence>
        {modal?.type === "config" && (
          <Modal onClose={() => { setModal(null); setToken("") }}>
            <div className="p-6">
              <div className="flex items-center gap-3 mb-5">
                <span className="text-3xl">{modal.platform.icon}</span>
                <div>
                  <h3 className="text-base font-bold text-white">Conectar {modal.platform.name}</h3>
                  <p className="text-xs text-slate-400">Cole seu access token abaixo</p>
                </div>
              </div>
              <div className="space-y-4">
                <div>
                  <label className="text-xs font-medium text-slate-300 block mb-1.5">🔑 Access Token</label>
                  <div className="relative">
                    <input type={showToken?"text":"password"} value={token}
                      onChange={e=>setToken(e.target.value)}
                      placeholder="Cole seu token aqui..."
                      className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 pr-10"/>
                    <button onClick={()=>setShowToken(!showToken)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white text-sm">
                      {showToken?"🙈":"👁️"}
                    </button>
                  </div>
                </div>
                <div className={`p-3 rounded-lg border ${modal.platform.bg} ${modal.platform.border}`}>
                  <p className="text-xs font-medium text-slate-300 mb-1">📖 Como obter:</p>
                  <p className="text-xs text-slate-400 mb-2">{modal.platform.tokenGuide}</p>
                  <a href={modal.platform.tokenUrl} target="_blank" rel="noopener noreferrer"
                    className={`text-xs font-medium ${modal.platform.color} hover:underline`}>
                    Abrir {modal.platform.name} Developers →
                  </a>
                </div>
                <div className="p-3 bg-slate-800 rounded-lg">
                  <p className="text-xs text-slate-400 mb-2">⚙️ Variaveis no <code className="text-blue-400">.env</code>:</p>
                  {modal.platform.envVars.map(v => (
                    <code key={v} className="block text-xs text-green-400 font-mono">{v}=sua_chave</code>
                  ))}
                </div>
                <div className="flex gap-2 pt-1">
                  <button onClick={()=>{setModal(null);setToken("")}}
                    className="flex-1 py-2.5 text-sm text-slate-400 border border-slate-700 rounded-lg hover:bg-slate-800">
                    Cancelar
                  </button>
                  <button onClick={()=>configMut.mutate({p:modal.platform.id,t:token})}
                    disabled={!token.trim()||configMut.isPending}
                    className={`flex-1 py-2.5 text-sm font-medium text-white rounded-lg border disabled:opacity-50 transition-all ${modal.platform.bg} ${modal.platform.border} hover:opacity-80`}>
                    {configMut.isPending?"🔄 Validando...":"✅ Conectar"}
                  </button>
                </div>
              </div>
            </div>
          </Modal>
        )}

        {modal?.type === "guide" && (
          <Modal onClose={()=>setModal(null)}>
            <div className="p-6">
              <div className="flex items-center gap-3 mb-5">
                <span className="text-3xl">{modal.platform.icon}</span>
                <div>
                  <h3 className="text-base font-bold text-white">📖 {modal.platform.name}</h3>
                  <p className="text-xs text-slate-400">Guia de configuracao</p>
                </div>
              </div>
              <div className="space-y-2 mb-4">
                {modal.platform.steps.map((s,i) => (
                  <div key={i} className="flex gap-3 items-start">
                    <div className={`w-5 h-5 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 mt-0.5 ${modal.platform.bg} ${modal.platform.color} border ${modal.platform.border}`}>
                      {i+1}
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed">{s}</p>
                  </div>
                ))}
              </div>
              <div className="bg-slate-800 rounded-lg p-3 mb-4">
                <p className="text-xs text-slate-400 mb-1">📄 No arquivo <code className="text-blue-400">.env</code>:</p>
                {modal.platform.envVars.map(v => (
                  <code key={v} className="block text-xs text-green-400 font-mono">{v}=sua_chave</code>
                ))}
              </div>
              <div className="flex gap-2">
                <a href={modal.platform.tokenUrl} target="_blank" rel="noopener noreferrer"
                  className="flex-1 py-2.5 text-xs text-center text-slate-300 border border-slate-700 rounded-lg hover:bg-slate-800 transition-colors">
                  📚 Documentacao
                </a>
                <button onClick={()=>setModal({type:"config",platform:modal.platform})}
                  className={`flex-1 py-2.5 text-xs font-medium rounded-lg border ${modal.platform.bg} ${modal.platform.color} ${modal.platform.border} hover:opacity-80`}>
                  🔑 Tenho meu Token
                </button>
              </div>
            </div>
          </Modal>
        )}

        {modal?.type === "details" && (
          <Modal onClose={()=>setModal(null)} wide>
            <DetailsPanel
              platform={modal.platform}
              integ={(integrations as Integration[]).find(i=>i.platform===modal.platform.id)}
              onDisconnect={()=>disconnectMut.mutate(modal.platform.id)}
              onSync={()=>syncMut.mutate(modal.platform.id)}
            />
          </Modal>
        )}
      </AnimatePresence>
    </div>
  )
}

function DetailsPanel({ platform, integ, onDisconnect, onSync }: {
  platform: PlatformCfg; integ?: Integration; onDisconnect: ()=>void; onSync: ()=>void
}) {
  const { data, isLoading } = useQuery({
    queryKey: ["int-data", platform.id],
    queryFn: async () => {
      if (platform.id === "facebook") return api.get("/integrations/facebook/data").then(r=>r.data).catch(()=>null)
      if (platform.id === "google" || platform.id === "maps") return api.get("/integrations/google/locations").then(r=>r.data).catch(()=>null)
      if (platform.id === "mercadolivre") return api.get("/integrations/mercadolivre/data").then(r=>r.data).catch(()=>null)
      return null
    },
    enabled: integ?.status === "connected",
  })

  return (
    <div>
      <div className={`p-6 ${platform.bg} border-b border-slate-800`}>
        <div className="flex items-start gap-4">
          <div className={`w-14 h-14 rounded-xl flex items-center justify-center text-3xl border ${platform.border} ${platform.bg}`}>{platform.icon}</div>
          <div className="flex-1">
            <h3 className="text-lg font-bold text-white">{platform.name}</h3>
            <p className={`text-sm font-medium ${platform.color}`}>{integ?.account_name||"—"}</p>
            <p className="text-xs text-slate-400">{integ?.account_email||""}</p>
          </div>
          <StatusBadge status={integ?.status||"disconnected"} />
        </div>
      </div>
      <div className="p-6 space-y-4">
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-slate-800 rounded-lg p-3">
            <p className="text-xs text-slate-400">Conectado em</p>
            <p className="text-sm font-medium text-white">{integ?.connected_at ? new Date(integ.connected_at).toLocaleDateString("pt-BR") : "—"}</p>
          </div>
          <div className="bg-slate-800 rounded-lg p-3">
            <p className="text-xs text-slate-400">Ultima sync</p>
            <p className="text-sm font-medium text-white">{integ?.last_sync ? new Date(integ.last_sync).toLocaleString("pt-BR",{timeStyle:"short",dateStyle:"short"}) : "—"}</p>
          </div>
        </div>

        {isLoading && <p className="text-xs text-slate-400 text-center py-4 animate-pulse">🔄 Carregando dados...</p>}

        {data && (
          <div className="bg-slate-800 rounded-lg p-4 space-y-2">
            <p className="text-xs font-semibold text-slate-300 uppercase tracking-wider mb-3">Dados da Plataforma</p>
            {platform.id === "facebook" && <>
              <div className="flex justify-between text-sm"><span className="text-slate-400">Paginas</span><span className="text-white font-medium">{data.pages?.length||0}</span></div>
              <div className="flex justify-between text-sm"><span className="text-slate-400">Total Seguidores</span><span className="text-white font-medium">{data.total_followers?.toLocaleString()||0}</span></div>
              {data.pages?.map((p:any)=>(
                <div key={p.id} className="flex justify-between text-xs pt-1 border-t border-slate-700">
                  <span className="text-slate-400">{p.name}</span>
                  <span className="text-blue-400">{p.fan_count?.toLocaleString()} fas</span>
                </div>
              ))}
            </>}
            {(platform.id === "google"||platform.id === "maps") && <>
              <div className="flex justify-between text-sm"><span className="text-slate-400">Locais</span><span className="text-white font-medium">{data.total||0}</span></div>
              {data.locations?.map((l:any,i:number)=>(
                <div key={i} className="text-xs pt-1 border-t border-slate-700"><p className="text-white">{l.title||l.name}</p></div>
              ))}
            </>}
            {platform.id === "mercadolivre" && <>
              <div className="flex justify-between text-sm"><span className="text-slate-400">Anuncios Ativos</span><span className="text-white font-medium">{data.active_items||0}</span></div>
              {data.reputation?.level_id && (
                <div className="flex justify-between text-sm"><span className="text-slate-400">Nivel Vendedor</span><span className="text-yellow-400 font-medium capitalize">{data.reputation.level_id}</span></div>
              )}
            </>}
          </div>
        )}

        <div className="flex gap-2 pt-2 border-t border-slate-800">
          <button onClick={onSync} className="flex-1 py-2 text-xs text-blue-400 border border-blue-500/30 rounded-lg hover:bg-blue-500/10 transition-colors">🔄 Sincronizar</button>
          <button onClick={()=>{if(confirm(`Desconectar ${platform.name}?`))onDisconnect()}} className="flex-1 py-2 text-xs text-red-400 border border-red-500/30 rounded-lg hover:bg-red-500/10 transition-colors">✕ Desconectar</button>
        </div>
      </div>
    </div>
  )
}
