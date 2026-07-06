"use client"
import { useState, useRef, useEffect } from "react"
import { useQuery } from "@tanstack/react-query"
import { getAgents, streamChat, clearAgentHistory } from "@/lib/api"
import { useAppStore } from "@/store/useAppStore"
import ReactMarkdown from "react-markdown"
import toast from "react-hot-toast"

const agentColors: Record<string, string> = {
  "hc-ceo": "from-purple-500 to-purple-700",
  "hc-seo": "from-green-500 to-green-700",
  "hc-social": "from-pink-500 to-pink-700",
  "hc-content": "from-orange-500 to-orange-700",
  "hc-code": "from-blue-500 to-blue-700",
}
const agentBorder: Record<string, string> = {
  "hc-ceo": "border-purple-500/40 bg-purple-500/5",
  "hc-seo": "border-green-500/40 bg-green-500/5",
  "hc-social": "border-pink-500/40 bg-pink-500/5",
  "hc-content": "border-orange-500/40 bg-orange-500/5",
  "hc-code": "border-blue-500/40 bg-blue-500/5",
}
const provLabel: Record<string, string> = {
  ollama: "🦙 Llama 3.2 Local", openai: "🟢 GPT-4o Mini", anthropic: "🟣 Claude Haiku"
}

export default function AgentsPage() {
  const { activeAgent, setActiveAgent, selectedProvider, conversations, addMessage, clearConversation } = useAppStore()
  const [input, setInput] = useState("")
  const [streaming, setStreaming] = useState(false)
  const [streamContent, setStreamContent] = useState("")
  const endRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  const { data: agents = [] } = useQuery({ queryKey: ["agents"], queryFn: () => getAgents().then(r => r.data) })
  const agent = (agents as any[]).find((a: any) => a.id === activeAgent)
  const messages = conversations[activeAgent] || []

  useEffect(() => { endRef.current?.scrollIntoView({behavior:"smooth"}) }, [messages, streamContent])
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = "auto"
      textareaRef.current.style.height = `${textareaRef.current.scrollHeight}px`
    }
  }, [input])

  const send = async () => {
    if (!input.trim() || streaming) return
    const userMsg = { role: "user" as const, content: input.trim() }
    addMessage(activeAgent, userMsg)
    setInput("")
    setStreaming(true)
    setStreamContent("")
    const allMsgs = [...messages, userMsg]
    try {
      let full = ""
      for await (const chunk of streamChat(allMsgs, { provider: selectedProvider, agent_id: activeAgent })) {
        if (chunk.type === "chunk" && chunk.content) {
          full += chunk.content
          setStreamContent(full)
        } else if (chunk.type === "error") {
          throw new Error(chunk.message || "Erro")
        }
      }
      addMessage(activeAgent, { role: "assistant", content: full })
      setStreamContent("")
    } catch (e: any) {
      toast.error(`Erro: ${e.message}`)
    } finally {
      setStreaming(false)
    }
  }

  const suggestions = ["Qual é minha estratégia atual?", "Crie um post para Instagram", "Analise meu SEO", "Gere um relatório"]

  return (
    <div className="flex gap-4 h-[calc(100vh-8rem)]">
      {/* Agent List */}
      <div className="w-56 flex-shrink-0 space-y-2 overflow-y-auto">
        <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-3">Agentes</p>
        {(agents as any[]).map((a: any) => (
          <button key={a.id} onClick={() => setActiveAgent(a.id)}
            className={`w-full text-left p-3 rounded-xl border transition-all ${activeAgent===a.id ? agentBorder[a.id]||"border-blue-500/40 bg-blue-500/5" : "border-slate-800 bg-slate-900 hover:border-slate-700"}`}>
            <div className="flex items-center gap-2">
              <span className="text-xl">{a.avatar}</span>
              <div className="flex-1 min-w-0">
                <p className="text-xs font-semibold text-white truncate">{a.name}</p>
                <p className="text-xs text-slate-400 truncate">{a.role}</p>
              </div>
              {activeAgent===a.id && <div className="w-1.5 h-1.5 bg-green-400 rounded-full animate-pulse"/>}
            </div>
            {activeAgent===a.id && <p className="text-xs text-slate-500 mt-2 line-clamp-2">{a.description}</p>}
          </button>
        ))}
      </div>

      {/* Chat */}
      <div className="flex-1 flex flex-col bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        {agent && (
          <div className="flex items-center justify-between p-4 border-b border-slate-800">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${agentColors[agent.id]} flex items-center justify-center text-xl`}>
                {agent.avatar}
              </div>
              <div>
                <h3 className="text-sm font-semibold text-white">{agent.name}</h3>
                <p className="text-xs text-slate-400">
                  <span className="text-green-400">● </span>{agent.role} • {provLabel[selectedProvider]}
                </p>
              </div>
            </div>
            <button onClick={() => { clearConversation(activeAgent); toast.success("Conversa limpa") }}
              className="text-xs text-slate-400 hover:text-red-400 border border-slate-700 px-3 py-1 rounded-lg transition-colors">
              🗑️ Limpar
            </button>
          </div>
        )}

        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.length===0 && !streaming && (
            <div className="flex flex-col items-center justify-center h-full text-center">
              <span className="text-5xl mb-4">{agent?.avatar||"🤖"}</span>
              <h3 className="text-sm font-semibold text-white mb-2">{agent?.name} pronto!</h3>
              <p className="text-xs text-slate-400 max-w-xs mb-6">{agent?.description}</p>
              <div className="space-y-2 w-full max-w-sm">
                {suggestions.map(s => (
                  <button key={s} onClick={() => setInput(s)}
                    className="w-full text-xs text-left px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-slate-300 transition-colors border border-slate-700">
                    {s}
                  </button>
                ))}
              </div>
            </div>
          )}
          {messages.map((m, i) => (
            <div key={i} className={`flex gap-3 ${m.role==="user"?"justify-end":"justify-start"}`}>
              {m.role==="assistant" && (
                <div className={`w-7 h-7 rounded-lg bg-gradient-to-br ${agentColors[activeAgent]||"from-blue-500 to-purple-600"} flex items-center justify-center text-sm flex-shrink-0 mt-1`}>
                  {agent?.avatar||"🤖"}
                </div>
              )}
              <div className={`max-w-[78%] rounded-xl px-4 py-3 ${m.role==="user"?"bg-blue-600 text-white":"bg-slate-800 text-slate-100"}`}>
                {m.role==="assistant"
                  ? <div className="prose prose-invert prose-sm max-w-none text-xs"><ReactMarkdown>{m.content}</ReactMarkdown></div>
                  : <p className="text-sm">{m.content}</p>}
              </div>
              {m.role==="user" && (
                <div className="w-7 h-7 rounded-lg bg-slate-700 flex items-center justify-center flex-shrink-0 mt-1 text-sm">👤</div>
              )}
            </div>
          ))}
          {streaming && (
            <div className="flex gap-3 justify-start">
              <div className={`w-7 h-7 rounded-lg bg-gradient-to-br ${agentColors[activeAgent]||"from-blue-500 to-purple-600"} flex items-center justify-center text-sm flex-shrink-0 mt-1`}>
                {agent?.avatar||"🤖"}
              </div>
              <div className="max-w-[78%] bg-slate-800 rounded-xl px-4 py-3">
                {streamContent
                  ? <div className="prose prose-invert prose-sm max-w-none text-xs"><ReactMarkdown>{streamContent}</ReactMarkdown></div>
                  : <div className="flex gap-1">{[0,1,2].map(i => <div key={i} className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce" style={{animationDelay:`${i*0.1}s`}}/>)}</div>}
              </div>
            </div>
          )}
          <div ref={endRef}/>
        </div>

        <div className="p-4 border-t border-slate-800">
          <div className="flex items-end gap-3">
            <textarea ref={textareaRef} value={input} onChange={e=>setInput(e.target.value)}
              onKeyDown={e=>{if(e.key==="Enter"&&!e.shiftKey){e.preventDefault();send()}}}
              placeholder={`Mensagem para ${agent?.name||"o agente"}...`} disabled={streaming} rows={1}
              className="flex-1 bg-slate-800 border border-slate-700 rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 resize-none focus:outline-none focus:border-blue-500 transition-colors min-h-[44px] max-h-32"/>
            <button onClick={send} disabled={!input.trim()||streaming}
              className="w-10 h-10 rounded-xl bg-blue-600 hover:bg-blue-500 disabled:opacity-50 flex items-center justify-center transition-all">
              {streaming ? <span className="text-white text-sm animate-spin">⟳</span> : <span className="text-white text-sm">➤</span>}
            </button>
          </div>
          <p className="text-xs text-slate-600 mt-1 text-center">Shift+Enter = nova linha • Enter = enviar • {provLabel[selectedProvider]}</p>
        </div>
      </div>
    </div>
  )
}