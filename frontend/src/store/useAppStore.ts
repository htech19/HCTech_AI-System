import { create } from "zustand"
import { persist } from "zustand/middleware"

type AIProvider = "ollama" | "openai" | "anthropic"
type ChatMessage = { role: "user" | "assistant" | "system"; content: string }

interface AppState {
  selectedProvider: AIProvider
  setSelectedProvider: (p: AIProvider) => void
  activeAgent: string
  setActiveAgent: (id: string) => void
  conversations: Record<string, ChatMessage[]>
  addMessage: (agentId: string, msg: ChatMessage) => void
  clearConversation: (agentId: string) => void
  currentPage: string
  setCurrentPage: (page: string) => void
  sidebarOpen: boolean
  setSidebarOpen: (open: boolean) => void
}

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      selectedProvider: "ollama",
      setSelectedProvider: (p) => set({ selectedProvider: p }),
      activeAgent: "hc-ceo",
      setActiveAgent: (id) => set({ activeAgent: id }),
      conversations: {},
      addMessage: (agentId, msg) => set((s) => ({
        conversations: { ...s.conversations, [agentId]: [...(s.conversations[agentId] || []), msg] }
      })),
      clearConversation: (agentId) => set((s) => ({
        conversations: { ...s.conversations, [agentId]: [] }
      })),
      currentPage: "dashboard",
      setCurrentPage: (page) => set({ currentPage: page }),
      sidebarOpen: true,
      setSidebarOpen: (open) => set({ sidebarOpen: open }),
    }),
    { name: "hctech-store", partialize: (s) => ({ selectedProvider: s.selectedProvider, activeAgent: s.activeAgent, sidebarOpen: s.sidebarOpen }) }
  )
)