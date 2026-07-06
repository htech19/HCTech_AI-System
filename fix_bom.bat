@echo off
title HC Tech AI - Corrigindo BOM e Reiniciando
color 0B
cd /d "C:\Users\hunlock\Documents\LOJA\Agente_Sistemas\Arena IA - Claude Sonnet"

echo.
echo ╔══════════════════════════════════════════╗
echo ║   HC TECH AI - Corrigindo arquivos...   ║
echo ╚══════════════════════════════════════════╝
echo.

echo [1] Removendo BOM de todos os arquivos frontend...

python -c "
import os, sys

root = r'C:\Users\hunlock\Documents\LOJA\Agente_Sistemas\Arena IA - Claude Sonnet'
frontend = os.path.join(root, 'frontend', 'src')
extra = [
    os.path.join(root, 'frontend', 'package.json'),
    os.path.join(root, 'frontend', 'tsconfig.json'),
    os.path.join(root, 'frontend', 'next.config.js'),
    os.path.join(root, 'frontend', 'tailwind.config.js'),
    os.path.join(root, 'frontend', 'postcss.config.js'),
]

fixed = 0
ok = 0
errors = 0

# Coletar todos os arquivos
all_files = extra[:]
for dirpath, dirnames, filenames in os.walk(frontend):
    dirnames[:] = [d for d in dirnames if d != 'node_modules']
    for filename in filenames:
        if filename.endswith(('.ts', '.tsx', '.js', '.jsx', '.json', '.css')):
            all_files.append(os.path.join(dirpath, filename))

for filepath in all_files:
    if not os.path.exists(filepath):
        continue
    try:
        with open(filepath, 'rb') as f:
            content = f.read()
        
        if content.startswith(b'\xef\xbb\xbf'):
            content = content[3:]
            with open(filepath, 'wb') as f:
                f.write(content)
            print(f'  FIXED: {os.path.relpath(filepath, root)}')
            fixed += 1
        else:
            ok += 1
    except Exception as e:
        print(f'  ERROR: {filepath}: {e}')
        errors += 1

print(f'')
print(f'  Resultado: {fixed} corrigidos, {ok} ok, {errors} erros')
print(f'  Total processados: {fixed + ok + errors}')
"

echo.
echo [2] Verificando package.json...
python -c "
import json, os
f = r'C:\Users\hunlock\Documents\LOJA\Agente_Sistemas\Arena IA - Claude Sonnet\frontend\package.json'
try:
    with open(f, 'r', encoding='utf-8') as fp:
        data = json.load(fp)
    print(f'  OK package.json valido - {data.get(\"name\", \"?\")} v{data.get(\"version\", \"?\")}')
except Exception as e:
    print(f'  ERRO package.json: {e}')
"

echo.
echo [3] Reescrevendo package.json limpo...

python -c "
import os, json

filepath = r'C:\Users\hunlock\Documents\LOJA\Agente_Sistemas\Arena IA - Claude Sonnet\frontend\package.json'

pkg = {
  'name': 'hctech-ai-frontend',
  'version': '2.1.0',
  'private': True,
  'scripts': {
    'dev': 'next dev -p 3000',
    'build': 'next build',
    'start': 'next start -p 3000',
    'type-check': 'tsc --noEmit'
  },
  'dependencies': {
    'next': '14.2.5',
    'react': '^18.3.0',
    'react-dom': '^18.3.0',
    'lucide-react': '^0.400.0',
    'recharts': '^2.12.0',
    'clsx': '^2.1.0',
    'tailwind-merge': '^2.3.0',
    'framer-motion': '^11.0.0',
    'zustand': '^4.5.0',
    '@tanstack/react-query': '^5.28.0',
    'axios': '^1.6.8',
    'react-hot-toast': '^2.4.1',
    'react-markdown': '^9.0.1'
  },
  'devDependencies': {
    '@types/node': '^20',
    '@types/react': '^18',
    '@types/react-dom': '^18',
    'typescript': '^5',
    'tailwindcss': '^3.4.0',
    'autoprefixer': '^10.4.19',
    'postcss': '^8.4.38',
    '@tailwindcss/typography': '^0.5.13'
  }
}

# Salvar sem BOM, com UTF-8 puro
content = json.dumps(pkg, indent=2, ensure_ascii=False)
with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)

print('  OK package.json reescrito (UTF-8 sem BOM)')

# Verificar
with open(filepath, 'rb') as f:
    inicio = f.read(4)
if inicio.startswith(b'\xef\xbb\xbf'):
    print('  ERRO ainda tem BOM!')
else:
    print('  OK sem BOM confirmado')
    print(f'  Primeiros bytes: {inicio.hex()}')
"

echo.
echo [4] Reescrevendo outros arquivos de config...

python -c "
import os

root = r'C:\Users\hunlock\Documents\LOJA\Agente_Sistemas\Arena IA - Claude Sonnet\frontend'

# next.config.js
next_config = '''/** @type {import(\"next\").NextConfig} */
const nextConfig = {
  reactStrictMode: false,
  env: {
    NEXT_PUBLIC_BACKEND_URL: process.env.NEXT_PUBLIC_BACKEND_URL || \"http://localhost:8000\",
    NEXT_PUBLIC_APP_VERSION: \"2.1.0\",
  },
}
module.exports = nextConfig
'''

# tailwind.config.js
tailwind_config = '''/** @type {import(\"tailwindcss\").Config} */
module.exports = {
  content: [\"./src/**/*.{js,ts,jsx,tsx,mdx}\"],
  theme: {
    extend: {
      animation: {
        \"fade-in\": \"fadeIn 0.3s ease-in-out\",
        \"slide-up\": \"slideUp 0.3s ease-out\",
      },
      keyframes: {
        fadeIn: {\"0%\": {opacity: \"0\"}, \"100%\": {opacity: \"1\"}},
        slideUp: {\"0%\": {transform: \"translateY(10px)\", opacity: \"0\"}, \"100%\": {transform: \"translateY(0)\", opacity: \"1\"}},
      }
    },
  },
  plugins: [require(\"@tailwindcss/typography\")],
}
'''

# postcss.config.js
postcss_config = '''module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
'''

# tsconfig.json
tsconfig = '''{
  \"compilerOptions\": {
    \"target\": \"es5\",
    \"lib\": [\"dom\", \"dom.iterable\", \"esnext\"],
    \"allowJs\": true,
    \"skipLibCheck\": true,
    \"strict\": false,
    \"noEmit\": true,
    \"esModuleInterop\": true,
    \"module\": \"esnext\",
    \"moduleResolution\": \"bundler\",
    \"resolveJsonModule\": true,
    \"isolatedModules\": true,
    \"jsx\": \"preserve\",
    \"incremental\": true,
    \"plugins\": [{\"name\": \"next\"}],
    \"paths\": {\"@/*\": [\"./src/*\"]}
  },
  \"include\": [\"next-env.d.ts\", \"**/*.ts\", \"**/*.tsx\", \".next/types/**/*.ts\"],
  \"exclude\": [\"node_modules\"]
}
'''

files = {
    'next.config.js': next_config,
    'tailwind.config.js': tailwind_config,
    'postcss.config.js': postcss_config,
    'tsconfig.json': tsconfig,
}

for filename, content in files.items():
    filepath = os.path.join(root, filename)
    with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    # Verificar sem BOM
    with open(filepath, 'rb') as f:
        inicio = f.read(3)
    status = 'ERRO BOM' if inicio.startswith(b'\xef\xbb\xbf') else 'OK'
    print(f'  {status} {filename}')
"

echo.
echo [5] Reescrevendo globals.css...

python -c "
import os

filepath = r'C:\Users\hunlock\Documents\LOJA\Agente_Sistemas\Arena IA - Claude Sonnet\frontend\src\app\globals.css'
os.makedirs(os.path.dirname(filepath), exist_ok=True)

content = '''@tailwind base;
@tailwind components;
@tailwind utilities;

* { box-sizing: border-box; }

::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: #334155; border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: #475569; }

.prose-invert {
  --tw-prose-body: #cbd5e1;
  --tw-prose-headings: #f1f5f9;
  --tw-prose-bold: #f1f5f9;
  --tw-prose-code: #93c5fd;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
'''

with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)

with open(filepath, 'rb') as f:
    inicio = f.read(3)
status = 'ERRO BOM' if inicio.startswith(b'\xef\xbb\xbf') else 'OK'
print(f'  {status} globals.css')
"

echo.
echo [6] Testando JSON valido...

python -c "
import json, os

root = r'C:\Users\hunlock\Documents\LOJA\Agente_Sistemas\Arena IA - Claude Sonnet\frontend'
files = ['package.json', 'tsconfig.json']

all_ok = True
for f in files:
    filepath = os.path.join(root, f)
    try:
        with open(filepath, 'r', encoding='utf-8') as fp:
            json.load(fp)
        print(f'  OK  {f}')
    except Exception as e:
        print(f'  FAIL {f}: {e}')
        all_ok = False

if all_ok:
    print('')
    print('  Todos JSONs validos!')
else:
    print('')
    print('  Alguns JSONs com erro - verifique acima')
"

echo.
echo [7] Iniciando Next.js...
echo     Aguarde ~30 segundos para o servidor subir...
echo.

cd /d "C:\Users\hunlock\Documents\LOJA\Agente_Sistemas\Arena IA - Claude Sonnet\frontend"
npm run dev