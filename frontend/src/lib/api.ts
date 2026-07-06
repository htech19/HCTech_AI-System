import axios from "axios"

const BASE = process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000"

export const api = axios.create({
  baseURL: `${BASE}/api`,
  timeout: 60000,
  headers: { "Content-Type": "application/json" },
})

api.interceptors.response.use(
  (r) => r,
  (e) => {
    console.error("[API]", e.response?.data?.detail || e.message)
    return Promise.reject(new Error(e.response?.data?.detail || e.message))
  }
)

export type AIProvider = "ollama" | "openai" | "anthropic"

// AI
export const getAIStatus = () => api.get("/ai/status")
export const chatWithAI = (data: object) => api.post("/ai/chat", data)
export const quickChat = (data: object) => api.post("/ai/quick", data)
export const generateReviewResponse = (data: object) => api.post("/ai/generate/review-response", data)
export const generateSocialPost = (data: object) => api.post("/social/generate-post", data)

// Agents
export const getAgents = () => api.get("/agents")
export const getAgent = (id: string) => api.get(`/agents/${id}`)
export const clearAgentHistory = (id: string) => api.delete(`/agents/${id}/history`)

// Tasks
export const getTasks = (status?: string) => api.get("/tasks", { params: { status } })
export const createTask = (data: object) => api.post("/tasks", data)
export const updateTask = (id: number, data: object) => api.put(`/tasks/${id}`, data)
export const deleteTask = (id: number) => api.delete(`/tasks/${id}`)
export const moveTask = (id: number, status: string) => api.patch(`/tasks/${id}/status`, { status })

// SEO
export const getSEOKeywords = () => api.get("/seo/keywords")
export const getSEOHealth = () => api.get("/seo/health")
export const generateSEOContent = (data: object) => api.post("/seo/generate-content", data)
export const runSEOAudit = () => api.post("/seo/audit")

// Maps / Reviews
export const getReviews = () => api.get("/maps/reviews")
export const autoRespondReview = (id: number) => api.post(`/maps/reviews/${id}/auto-respond`)
export const getMapsProfile = () => api.get("/maps/profile")

// Social
export const getSocialPosts = (platform?: string) => api.get("/social/posts", { params: { platform } })
export const getSocialMetrics = () => api.get("/social/metrics")
export const createSocialPost = (data: object) => api.post("/social/posts", data)

// Knowledge
export const getKnowledge = (search?: string, category?: string) => api.get("/knowledge", { params: { search, category } })
export const createArticle = (data: object) => api.post("/knowledge", data)
export const deleteArticle = (id: number) => api.delete(`/knowledge/${id}`)

// Metrics
export const getDashboardMetrics = () => api.get("/metrics/dashboard")

// Reports
export const generateReport = (type: string) => api.post("/reports/generate", { type })
export const getReports = () => api.get("/reports")

// Automation
export const getAutomationJobs = () => api.get("/automation/jobs")
export const toggleJob = (id: number, active: boolean) => api.patch(`/automation/jobs/${id}/toggle`, { active })
export const runJobNow = (id: number) => api.post(`/automation/jobs/${id}/run`)

// Streaming
export async function* streamChat(
  messages: { role: string; content: string }[],
  options: { provider?: string; agent_id?: string } = {}
) {
  const res = await fetch(`${BASE}/api/ai/chat/stream`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ messages, ...options }),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  const reader = res.body!.getReader()
  const dec = new TextDecoder()
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    const text = dec.decode(value)
    for (const line of text.split("\n")) {
      if (line.startsWith("data: ")) {
        try { yield JSON.parse(line.slice(6)) } catch {}
      }
    }
  }
}