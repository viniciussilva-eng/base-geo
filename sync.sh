#!/bin/bash

# ====================================================================
# Script de Sincronização com GitHub v3.1 (Modo Seguro e Forçado)
#
# Uso:
#   ./sync.sh        -> Executa o modo de sincronização padrão e seguro.
#   ./sync.sh force  -> Executa o modo forçado (espelho local -> remoto).
# ====================================================================

# --- Configuração ---
set -e # Aborta o script se qualquer comando falhar

REPO_URL="git@github.com:viniciussilva-eng/base-geo.git"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Função de log
log() {
    echo -e "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# --- Início do Script ---
log "${BLUE}============================================${NC}"
log "${BLUE}  INICIANDO SCRIPT DE SINCRONIZAÇÃO v3.1      ${NC}"
log "${BLUE}============================================${NC}"

# 1. VALIDAÇÕES E SETUP INICIAL
PROJETO_DIR=$(pwd)
log "${YELLOW}📁 Projeto: $PROJETO_DIR${NC}"

if ! git --version &>/dev/null; then
    log "${RED}❌ Git não está instalado. Abortando.${NC}"
    exit 1
fi

git config --global --add safe.directory "$PROJETO_DIR"

if [ ! -d ".git" ]; then
    log "${GREEN}✅ Repositório não encontrado. Inicializando...${NC}"
    git init
    git branch -M main
fi

# 2. CONFIGURAÇÃO DO REMOTO (SSH)
log "${BLUE}🔧 Configurando remoto para usar SSH: $REPO_URL${NC}"
git remote set-url origin "$REPO_URL" 2>/dev/null || git remote add origin "$REPO_URL"
git lfs install

# 3. SELEÇÃO DO MODO DE OPERAÇÃO
if [[ "$1" == "force" ]]; then
    # ==================== MODO FORÇADO (ESPELHO) ====================
    log "${RED}🚨 MODO FORÇADO ATIVADO! 🚨${NC}"
    log "${YELLOW}Este modo fará o repositório remoto ser um ESPELHO EXATO da sua pasta local."
    log "${YELLOW}Qualquer commit ou arquivo que exista no GitHub mas não aqui será APAGADO PERMANENTEMENTE.${NC}"
    read -p "Você tem certeza que deseja continuar? (s/N): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        log "${GREEN}Operação cancelada pelo usuário.${NC}"
        exit 0
    fi

    log "${BLUE}📦 Adicionando todas as alterações locais (novos, modificados, deletados)...${NC}"
    git add .

    log "${BLUE}✏️  Criando commit de espelhamento...${NC}"
    # O || true evita que o script pare se não houver nada para commitar
    git commit -m "refactor(force): Sincronização forçada para espelhar estado local em $(date +"%Y-%m-%d %H:%M")" || true

    log "${RED}🚀 Executando PUSH FORÇADO... Sobrescrevendo o remoto...${NC}"
    git push --force origin main

else
    # ==================== MODO PADRÃO (SEGURO) ====================
    log "${GREEN}▶️  Executando em modo de sincronização padrão (seguro).${NC}"

    log "${BLUE}🔄 Puxando alterações do remoto (pull --rebase)...${NC}"
    if ! git pull --rebase origin main; then
        log "${RED}❌ Falha no 'git pull'. Resolva os conflitos ou limpe as alterações locais e tente novamente.${NC}"
        exit 1
    fi

    log "${BLUE}🔄 Atualizando submódulos com as versões remotas...${NC}"
    git submodule update --remote --merge

    log "${YELLOW}🔍 Detectando arquivos grandes (>50MB) para Git LFS...${NC}"
    ARQUIVOS_GRANDES=$(find . -type f -size +50M -not -path "./.git/*")
    if [ -n "$ARQUIVOS_GRANDES" ]; then
        log "${YELLOW}Arquivos grandes detectados. Rastreando com LFS...${NC}"
        echo "$ARQUIVOS_GRANDES" | while read -r arquivo; do git lfs track "${arquivo#./}"; done
        git add .gitattributes
    fi

    if [ -z "$(git status --porcelain)" ]; then
        log "${GREEN}✅ Não há novas alterações locais para enviar. Sincronização concluída.${NC}"
        exit 0
    fi

    log "${BLUE}📦 Adicionando alterações locais...${NC}"
    git add .

    log "${BLUE}✏️  Criando commit...${NC}"
    git commit -m "feat(auto): Sincronização de arquivos em $(date +"%Y-%m-%d %H:%M")"

    log "${GREEN}🚀 Enviando alterações para o remoto (push)...${NC}"
    git push origin main
fi

# Envia objetos LFS, se houver
log "${BLUE}📤 Enviando arquivos grandes via Git LFS...${NC}"
git lfs push --all origin main

# --- RELATÓRIO FINAL ---
log "${GREEN}============================================${NC}"
log "${GREEN}   SINCRONIZAÇÃO CONCLUÍDA COM SUCESSO!     ${NC}"
log "${GREEN}============================================${NC}"
log "${YELLOW}Último commit:${NC}"
git log -1 --pretty=format:"%h - %s (%cr)"
log "${GREEN}============================================${NC}"

exit 0
