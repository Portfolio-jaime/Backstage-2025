#!/bin/bash

echo "🚀 Iniciando Backstage en modo desarrollo..."

# Verificar si Docker está corriendo
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Docker no está funcionando. Inicia Docker Desktop primero."
    exit 1
fi

# Iniciar servicios de base de datos
echo "📦 Iniciando PostgreSQL y Redis..."
cd docker
docker-compose up -d postgres redis

# Esperar a que PostgreSQL esté listo
echo "⏳ Esperando a que PostgreSQL esté listo..."
until docker-compose exec postgres pg_isready -U backstage; do
  sleep 1
done

echo "✅ Base de datos lista"

# Volver al directorio raíz
cd ..

# Instalar dependencias si no están instaladas
if [ ! -d "node_modules" ]; then
    echo "📦 Instalando dependencias..."
    yarn install
fi

echo "🎯 Iniciando Backstage..."
echo "Frontend: http://localhost:3000"
echo "Backend: http://localhost:7007" 
echo ""

# Iniciar Backstage
yarn dev
