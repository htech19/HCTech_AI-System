# Google Maps Platform — API Key e APIs principais

## Passo a passo

### 1. Criar/selecionar projeto no Google Cloud
1. Acesse https://console.cloud.google.com
2. Crie um projeto novo (ou reutilize um existente da HC Tech) em **"Selecionar projeto" → "Novo Projeto"**.
3. Ative o **faturamento** (Billing) — obrigatório mesmo usando a cota gratuita mensal (US$200 de crédito recorrente para Maps Platform).

### 2. Ativar as APIs necessárias
Em **"APIs e Serviços" → "Biblioteca"**, ativar conforme o uso:
| API | Uso típico HC Tech |
|---|---|
| Maps JavaScript API | Exibir mapa embutido no site (localização da loja) |
| Places API | Autocomplete de endereço, busca de estabelecimentos próximos |
| Geocoding API | Converter endereço em coordenadas (lat/lng) e vice-versa |
| Distance Matrix API | Calcular distância/tempo entre loja e cliente (frete, atendimento) |
| Directions API | Rotas para entrega/coleta |

### 3. Criar a chave de API
1. **"APIs e Serviços" → "Credenciais" → "Criar credenciais" → "Chave de API"**.
2. **Restringir a chave imediatamente** (obrigatório em produção):
   - **Restrições de aplicativo**: "Referenciadores HTTP" (para uso no site) informando o domínio `hctechinfocell.com.br/*`, ou "Endereços IP" se for uso server-side.
   - **Restrições de API**: marcar apenas as APIs realmente usadas (nunca deixar "Não restringir").

### 4. Uso básico — Geocoding
```bash
curl "https://maps.googleapis.com/maps/api/geocode/json?address=Av.+Paulista,+São+Paulo&key=API_KEY"
```

### 5. Uso básico — Places Autocomplete (para formulários de endereço)
```bash
curl "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Rua+Augusta&key=API_KEY&language=pt-BR&components=country:br"
```

### 6. Embutir mapa no site (Maps JavaScript API)
```html
<script async
  src="https://maps.googleapis.com/maps/api/js?key=API_KEY&callback=initMap">
</script>
<script>
function initMap() {
  const loja = { lat: -23.6944, lng: -46.5654 }; // São Bernardo do Campo
  const map = new google.maps.Map(document.getElementById("map"), {
    zoom: 15,
    center: loja,
  });
  new google.maps.Marker({ position: loja, map });
}
</script>
```

## Custos e cota
- Google concede US$200/mês de crédito recorrente — cobre a maior parte do uso de uma loja/negócio local com tráfego moderado.
- Configurar **alertas de orçamento** (Billing → Orçamentos e alertas) para não ser surpreendido.

## Boas práticas
- Nunca expor a chave sem restrição de domínio/API no front-end.
- Para chamadas server-side (backend Node.js/Python do HC-TECH-AI), usar uma chave **separada**, restrita por IP, nunca a mesma do front-end.
- Cachear resultados de Geocoding (endereços não mudam) para reduzir custo e latência.
