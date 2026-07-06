"use client"
import { useAppStore } from "@/store/useAppStore"

const nav = [
  { id: "dashboard",    label: "Dashboard",          icon: "📊" },
  { id: "agents",       label: "Agentes IA",          icon: "🤖" },
  { id: "kanban",       label: "Kanban",              icon: "📋" },
  { id: "seo",          label: "SEO Manager",         icon: "🔍" },
  { id: "social",       label: "Social Hub",          icon: "📱" },
  { id: "maps",         label: "Google Maps",         icon: "📍" },
  { id: "integrations", label: "Integracoes",         icon: "🔗" },
  { id: "knowledge",    label: "Conhecimento",        icon: "📚" },
  { id: "reports",      label: "Relatorios",          icon: "📈" },
  { id: "automation",   label: "Automacao",           icon: "⚙️" },
  { id: "settings",     label: "Configuracoes",       icon: "🛠️" },
]

const providerInfo: Record<string, { label: string; color: string; dot: string }> = {
  ollama:    { label: "Ollama Local", color: "text-green-400  bg-green-400/10  border-green-400/30",  dot: "bg-green-400"  },
  openai:    { label: "OpenAI GPT",   color: "text-blue-400   bg-blue-400/10   border-blue-400/30",   dot: "bg-blue-400"   },
  anthropic: { label: "Claude AI",    color: "text-purple-400 bg-purple-400/10 border-purple-400/30", dot: "bg-purple-400" },
}

export default function Sidebar() {
  const {
    currentPage,
    setCurrentPage,
    sidebarOpen,
    setSidebarOpen,
    selectedProvider,
  } = useAppStore()

  const pi = providerInfo[selectedProvider] || providerInfo.ollama

  return (
    <aside
      style={{ width: sidebarOpen ? 240 : 64 }}
      className="fixed left-0 top-0 h-full bg-slate-900 border-r border-slate-800 flex flex-col z-50 transition-all duration-300 overflow-hidden"
    >
      {/* Logo */}
      <div className="flex items-center h-16 px-4 border-b border-slate-800 gap-3">
        <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center flex-shrink-0 text-sm">
          🤖
        </div>
        {sidebarOpen && (
          <div className="flex-1 min-w-0">
            <p className="text-sm font-bold text-white truncate">HC Tech AI</p>
            <p className="text-xs text-slate-400">v2.1 Sistema</p>
          </div>
        )}
        <button
          onClick={() => setSidebarOpen(!sidebarOpen)}
          className="text-slate-400 hover:text-white text-lg flex-shrink-0 ml-auto"
        >
          {sidebarOpen ? "◀" : "▶"}
        </button>
      </div>

      {/* AI Provider Badge */}
      {sidebarOpen && (
        <div className="px-4 py-2 border-b border-slate-800">
          <div
            className={`flex items-center gap-2 px-2 py-1 rounded-md text-xs font-medium border ${pi.color}`}
          >
            <div className={`w-1.5 h-1.5 rounded-full ${pi.dot} animate-pulse`} />
            {selectedProvider === "ollama"    && "🦙 "}
            {selectedProvider === "openai"    && "🟢 "}
            {selectedProvider === "anthropic" && "🟣 "}
            {pi.label}
          </div>
        </div>
      )}

      {/* Navigation */}
      <nav className="flex-1 py-4 space-y-0.5 px-2 overflow-y-auto overflow-x-hidden">
        {nav.map((item) => {
          const isActive = currentPage === item.id
          return (
            <button
              key={item.id}
              onClick={() => setCurrentPage(item.id)}
              title={!sidebarOpen ? `${item.icon} ${item.label}` : undefined}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all group ${
                isActive
                  ? "bg-slate-800 text-white font-medium"
                  : "text-slate-400 hover:bg-slate-800/50 hover:text-white"
              }`}
            >
              <span className="text-base flex-shrink-0">{item.icon}</span>
              {sidebarOpen && (
                <span className="truncate">{item.label}</span>
              )}
              {isActive && sidebarOpen && (
                <div className="ml-auto w-1.5 h-1.5 rounded-full bg-blue-400 flex-shrink-0" />
              )}
            </button>
          )
        })}
      </nav>

      {/* Footer */}
      <div className="p-4 border-t border-slate-800">
        {sidebarOpen ? (
          <div className="text-center">
            <p className="text-xs text-slate-500">HC Tech AI System</p>
            <p className="text-xs text-slate-600">v2.1.0 © 2024</p>
          </div>
        ) : (
          <div
            className="w-2 h-2 rounded-full bg-green-400 mx-auto animate-pulse"
            title="Sistema Online"
          />
        )}
      </div>
    </aside>
  )
}
