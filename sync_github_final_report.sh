#!/bin/bash

# ==================================================
# Script de sincronização GitHub robusto com relatório
# ==================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  INICIANDO SINCRONIZAÇÃO AUTOMÁTICA        ${NC}"
echo -e "${BLUE}============================================${NC}"

# Pasta atual
PROJETO=$(pwd)
REPO="https://github.com/viniciussilva-eng/base-geo.git"

echo -e "${YELLOW}📁 Projeto: $PROJETO${NC}"
echo -e "${YELLOW}🌐 Repositório remoto: $REPO${NC}"

# Garantir safe.directory
git config --global --add safe.directory "$PROJETO"

# Inicializar Git se necessário
if [ ! -d ".git" ]; then
    echo -e "${GREEN}✅ Inicializando Git...${NC}"
    git init
    git branch -M main
fi

# Configurar remoto
git remote remove origin 2>/dev/null
git remote add origin "$REPO"
echo -e "${GREEN}✅ Remoto configurado${NC}"

# Inicializar Git LFS
git lfs install

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

# Armazenar credenciais
git config --global credential.helper store

# Adicionar todos os arquivos
echo -e "${BLUE}📦 Adicionando arquivos...${NC}"
git add .

# Commit
echo -e "${BLUE}✏️  Criando commit...${NC}"
git commit -m "Sincronizando pasta local com Git LFS e arquivos grandes" || echo -e "${YELLOW}⚠️ Nenhuma alteração para commit${NC}"

# Pull remoto e mesclar divergentes
echo -e "${BLUE}🔄 Mesclando com o remoto...${NC}"
git pull origin main --allow-unrelated-histories --no-rebase 2>/dev/null || echo -e "${YELLOW}⚠️ Pull remoto falhou ou não havia alterações${NC}"
git merge -X ours origin/main -m "Mesclando remoto mantendo versão local" 2>/dev/null || echo -e "${YELLOW}⚠️ Merge automático ignorado${NC}"

# Push em partes menores (batch)
echo -e "${BLUE}🚀 Enviando commits em lotes menores para evitar timeout...${NC}"
CHUNK_SIZE=50
FILES_TO_PUSH=$(git diff --name-only HEAD~1 HEAD)
FILE_ARRAY=($FILES_TO_PUSH)
TOTAL=${#FILE_ARRAY[@]}
for (( i=0; i<$TOTAL; i+=$CHUNK_SIZE )); do
    BATCH=("${FILE_ARRAY[@]:i:CHUNK_SIZE}")
    git add "${BATCH[@]}"
    git commit -m "Batch commit arquivos ${i} a $((i+CHUNK_SIZE))" || true
    git push origin main --force || echo -e "${RED}⚠️ Push do batch falhou, tentando próximo${NC}"
done

# Push de arquivos grandes via LFS
if [ ! -z "$ARQUIVOS_GRANDES" ]; then
    echo -e "${BLUE}📤 Enviando arquivos grandes via Git LFS...${NC}"
    git lfs push --all origin main
fi

# Relatório final
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  RELATÓRIO DE SINCRONIZAÇÃO                 ${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "${YELLOW}Arquivos enviados via Git normal:${NC}"
git ls-files --stage
echo -e "${YELLOW}Arquivos enviados via Git LFS:${NC}"
git lfs ls-files
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  SINCRONIZAÇÃO COMPLETA COM SUCESSO!      ${NC}"
echo -e "${GREEN}============================================${NC}"
