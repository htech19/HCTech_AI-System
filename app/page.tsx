export default function HomePage() {
  const agentes = [
    { nome: 'HC-CEO', papel: 'Orquestrador', status: 'ativo' },
    { nome: 'HC-SEO', papel: 'Otimizacao e SEO', status: 'ativo' },
    { nome: 'HC-CONTENT', papel: 'Geracao de conteudo', status: 'ativo' },
    { nome: 'HC-LEADS', papel: 'Captacao de leads', status: 'ativo' },
    { nome: 'HC-CODE', papel: 'Automacao e codigo', status: 'ativo' },
  ];

  return (
    <main className="min-h-screen bg-brand-dark text-white p-8">
      <header className="mb-8">
        <h1 className="text-3xl font-bold text-brand-green">HC Tech AI System v2.1</h1>
        <p className="text-brand-silver mt-1">Plataforma Hibrida Local/Online de IA para Assistencias Tecnicas</p>
      </header>
      <section>
        <h2 className="text-xl font-semibold mb-4">Agentes</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {agentes.map((agente) => (
            <div key={agente.nome} className="rounded-lg border border-neutral-800 bg-neutral-900 p-4">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold">{agente.nome}</h3>
                <span className="text-xs px-2 py-0.5 rounded-full bg-brand-green/20 text-brand-green">{agente.status}</span>
              </div>
              <p className="text-sm text-brand-silver mt-1">{agente.papel}</p>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}