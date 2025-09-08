#!/bin/bash

# ====================================================================
# Script de Sincronização com GitHub v4.0 (Interativo)
#
# Detecta e oferece correção para novos submódulos.
# Uso:
#   ./sync.sh        -> Executa o modo de sincronização padrão e seguro.
#   ./sync.sh force  -> Executa o modo forçado (espelho local -> remoto).
# ====================================================================

# --- Configuração ---
set -e 

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
log "${BLUE}  INICIANDO SCRIPT DE SINCRONIZAÇÃO v4.0      ${NC}"
log "${BLUE}============================================${NC}"

PROJETO_DIR=$(pwd)
log "${YELLOW}📁 Projeto: $PROJETO_DIR${NC}"

# 1. VALIDAÇÕES E SETUP INICIAL
git config --global --add safe.directory "$PROJETO_DIR"
if [ ! -d ".git" ]; then git init && git branch -M main; fi

# 2. CONFIGURAÇÃO DO REMOTO (SSH)
log "${BLUE}🔧 Configurando remoto para usar SSH: $REPO_URL${NC}"
git remote set-url origin "$REPO_URL" 2>/dev/null || git remote add origin "$REPO_URL"
git lfs install

# 3. SELEÇÃO DO MODO DE OPERAÇÃO
if [[ "$1" == "force" ]]; then
    # ==================== MODO FORÇADO (ESPELHO) ====================
    log "${RED}🚨 MODO FORÇADO ATIVADO! 🚨${NC}"
    log "${YELLOW}Este modo fará o repositório remoto ser um ESPELHO EXATO da sua pasta local.${NC}"
    read -p "Você tem certeza que deseja continuar? (s/N): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then log "${GREEN}Operação cancelada.${NC}" && exit 0; fi

    git add .
    log "${BLUE}✏️  Criando commit de espelhamento...${NC}"
    git commit -m "refactor(force): Sincronização forçada para espelhar estado local em $(date +"%Y-%m-%d %H:%M")" || true
    log "${RED}🚀 Executando PUSH FORÇADO...${NC}"
    git push --force origin main

else
    # ==================== MODO PADRÃO (SEGURO) ====================
    log "${GREEN}▶️  Executando em modo de sincronização padrão (seguro).${NC}"

    log "${BLUE}🔄 Puxando alterações do remoto (pull --rebase)...${NC}"
    git pull --rebase origin main

    log "${BLUE}🔄 Atualizando submódulos com as versões remotas...${NC}"
    git submodule update --remote --merge

    log "${YELLOW}🔍 Detectando arquivos grandes (>50MB) para Git LFS...${NC}"
    # Implementação mais robusta para detecção de LFS
    find . -type f -size +50M -not -path "./.git/*" -print0 | while IFS= read -r -d '' file; do
        if ! git lfs ls-files | grep -qF "./${file#./}"; then
            log "${GREEN}   + Rastreando novo arquivo grande: ${file#./}${NC}"
            git lfs track "${file#./}"
            git add .gitattributes
        fi
    done

    # Adiciona todas as alterações antes de verificar por submódulos
    git add .

    # ==================== NOVA FUNÇÃO: DETECÇÃO DE SUBMÓDULOS ====================
    log "${YELLOW}🔍 Verificando se novas pastas foram adicionadas como submódulos...${NC}"
    # Comando para encontrar novos submódulos adicionados ao stage
    git diff --cached --raw | grep -E '160000 A' | cut -d'	' -f2 | while read -r submodule_path; do
        log "${YELLOW}⚠️  DETECTADO: A pasta '${submodule_path}' foi adicionada como um submódulo (contém uma pasta .git).${NC}"
        read -p "   -> Deseja convertê-la em uma pasta comum, adicionando seus arquivos ao projeto principal? (S/n): " choice
        
        # Default para 'Sim' se o usuário apenas pressionar Enter
        choice=${choice:-S}

        if [[ "$choice" == "S" || "$choice" == "s" ]]; then
            log "${GREEN}   ✅ Convertendo '${submodule_path}' para um diretório comum...${NC}"
            git rm --cached "$submodule_path"
            rm -rf "$submodule_path/.git"
            git add "$submodule_path"
            log "${GREEN}   Conversão concluída. O commit continuará com a pasta corrigida.${NC}"
        else
            log "${YELLOW}   Ok, mantendo '${submodule_path}' como um submódulo.${NC}"
        fi
    done
    # ==========================================================================

    if [ -z "$(git status --porcelain)" ]; then
        log "${GREEN}✅ Não há novas alterações locais para enviar. Sincronização concluída.${NC}"
        exit 0
    fi

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
