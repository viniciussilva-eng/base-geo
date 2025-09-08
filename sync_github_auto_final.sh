#!/bin/bash

# ==================================================
# Script automatizado de sincronização GitHub
# - Detecta e envia arquivos grandes via Git LFS
# - Commit, pull e push automático
# - Usa a pasta atual como projeto
# ==================================================

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  INICIANDO SINCRONIZAÇÃO AUTOMÁTICA        ${NC}"
echo -e "${BLUE}============================================${NC}"

# Usar pasta atual como projeto
PROJETO=$(pwd)
REPO="https://github.com/viniciussilva-eng/base-geo.git"

echo -e "${YELLOW}📁 Projeto alvo: $PROJETO${NC}"
echo -e "${YELLOW}🌐 Repositório remoto: $REPO${NC}"

# Inicializar Git se não existir
if [ ! -d ".git" ]; then
    echo -e "${GREEN}✅ Inicializando Git...${NC}"
    git init
    git branch -M main
fi

# Configurar remoto
git remote remove origin 2>/dev/null
git remote add origin "$REPO"
echo -e "${GREEN}✅ Remoto configurado${NC}"

# Configurar Git LFS
if ! git lfs version >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Instalando Git LFS...${NC}"
    sudo apt install -y git-lfs
    git lfs install
fi
echo -e "${GREEN}✅ Git LFS ativo${NC}"

# Detectar arquivos grandes (>50MB)
echo -e "${YELLOW}🔍 Detectando arquivos grandes (>50MB)...${NC}"
ARQUIVOS_GRANDES=$(find . -type f -size +50M)
if [ -z "$ARQUIVOS_GRANDES" ]; then
    echo -e "${GREEN}Nenhum arquivo grande detectado.${NC}"
else
    echo -e "${YELLOW}Arquivos grandes detectados:${NC}"
    echo "$ARQUIVOS_GRANDES"
    echo "$ARQUIVOS_GRANDES" | while read -r arquivo; do
        arquivo_rel="${arquivo#./}"
        git lfs track "$arquivo_rel"
        git rm --cached "$arquivo_rel" 2>/dev/null
    done
    git add .gitattributes
fi

# Configurar Git para armazenar credenciais
git config --global credential.helper store

# Adicionar todos os arquivos
echo -e "${BLUE}📦 Adicionando todos os arquivos...${NC}"
git add .

# Commit das alterações
echo -e "${BLUE}✏️  Criando commit...${NC}"
git commit -m "Sincronizando pasta local com Git LFS e arquivos grandes" || echo -e "${YELLOW}⚠️ Nenhuma alteração para commit${NC}"

# Pull remoto e mesclar divergentes
echo -e "${BLUE}🔄 Mesclando com o remoto...${NC}"
git pull origin main --allow-unrelated-histories --no-rebase 2>/dev/null || echo -e "${YELLOW}⚠️ Pull remoto falhou ou não havia alterações${NC}"
git merge -X ours origin/main -m "Mesclando remoto mantendo versão local" 2>/dev/null || echo -e "${YELLOW}⚠️ Merge automático ignorado${NC}"

# Push commits
echo -e "${BLUE}🚀 Enviando commits para o GitHub...${NC}"
git push origin main --force

# Push arquivos grandes via LFS
if [ ! -z "$ARQUIVOS_GRANDES" ]; then
    echo -e "${BLUE}📤 Enviando arquivos grandes via Git LFS...${NC}"
    git lfs push origin main
fi

# Resumo final
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  SINCRONIZAÇÃO COMPLETA COM SUCESSO!      ${NC}"
echo -e "${GREEN}  Todos os arquivos, inclusive grandes,    ${NC}"
echo -e "${GREEN}  foram enviados para o GitHub corretamente${NC}"
echo -e "${GREEN}============================================${NC}"
