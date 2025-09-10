#!/bin/bash

# ====================================================================
# Script de Sincronização com GitHub v5.0 (Interativo e Robusto)
#
# Resolve automaticamente "unstaged changes" antes do pull.
# Detecta e oferece correção para novos submódulos.
# Logs detalhados em português para melhor compreensão.
#
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

# Função de log aprimorada
log() {
    echo -e "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# --- Início do Script ---
log "${BLUE}============================================${NC}"
log "${BLUE}  INICIANDO SCRIPT DE SINCRONIZAÇÃO v5.0      ${NC}"
log "${BLUE}============================================${NC}"

PROJETO_DIR=$(pwd)
log "${YELLOW}📁 Projeto localizado em: $PROJETO_DIR${NC}"

# 1. VALIDAÇÕES E SETUP INICIAL
git config --global --add safe.directory "$PROJETO_DIR"
if [ ! -d ".git" ]; then 
    log "${YELLOW}⚠️  Repositório .git não encontrado. Inicializando um novo...${NC}"
    git init && git branch -M main
fi

# 2. CONFIGURAÇÃO DO REMOTO (SSH)
log "${BLUE}🔧 Verificando e configurando o repositório remoto (SSH): $REPO_URL${NC}"
git remote set-url origin "$REPO_URL" 2>/dev/null || git remote add origin "$REPO_URL"
git lfs install

# 3. SELEÇÃO DO MODO DE OPERAÇÃO
if [[ "$1" == "force" ]]; then
    # ==================== MODO FORÇADO (ESPELHO) ====================
    log "${RED}🚨 MODO FORÇADO ATIVADO! 🚨${NC}"
    log "${YELLOW}Este modo fará o repositório remoto ser um ESPELHO EXATO da sua pasta local.${NC}"
    log "${RED}AVISO: Commits existentes no remoto que não estão no local serão perdidos.${NC}"
    read -p "Você tem certeza que deseja continuar? (s/N): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then log "${GREEN}Operação cancelada pelo usuário.${NC}" && exit 0; fi

    log "${BLUE}➕ Adicionando todos os arquivos ao stage...${NC}"
    git add .
    log "${BLUE}✏️  Criando commit de espelhamento...${NC}"
    git commit -m "refactor(force): Sincronização forçada para espelhar estado local em $(date +"%Y-%m-%d %H:%M")" || true
    log "${RED}🚀 Executando PUSH FORÇADO para 'main'...${NC}"
    git push --force origin main

else
    # ==================== MODO PADRÃO (SEGURO) ====================
    log "${GREEN}▶️  Executando em modo de sincronização padrão (seguro).${NC}"

    # ===== NOVA ROTINA: VERIFICAÇÃO DE ALTERAÇÕES LOCAIS (STASH AUTOMÁTICO) =====
    log "${YELLOW}🔍 Verificando o estado do diretório de trabalho...${NC}"
    STASH_APPLIED=false
    if [ -n "$(git status --porcelain)" ]; then
        log "${YELLOW}⚠️  Detectadas alterações locais não salvas. Guardando-as temporariamente (git stash)...${NC}"
        git stash push -m "sync.sh: Stash automático antes da sincronização"
        STASH_APPLIED=true
        log "${GREEN}   ✅ Alterações locais guardadas com sucesso.${NC}"
    else
        log "${GREEN}✅ Diretório de trabalho está limpo. Nenhuma alteração local para guardar.${NC}"
    fi
    # ==========================================================================

    log "${BLUE}🔄 Sincronizando com o repositório remoto (pull --rebase)...${NC}"
    git pull --rebase origin main

    log "${BLUE}🔄 Atualizando submódulos (se houver) com as versões remotas...${NC}"
    git submodule update --remote --merge

    # ===== RESTAURAÇÃO DAS ALTERAÇÕES LOCAIS (STASH POP) =====
    if [ "$STASH_APPLIED" = true ]; then
        log "${BLUE}🔄 Restaurando suas alterações locais que foram guardadas...${NC}"
        if git stash pop; then
            log "${GREEN}   ✅ Alterações restauradas com sucesso.${NC}"
        else
            log "${RED}🚨 CONFLITO AO RESTAURAR! 🚨 Não foi possível reaplicar suas alterações automaticamente.${NC}"
            log "${YELLOW}   -> Suas alterações ainda estão salvas no stash. Resolva os conflitos indicados nos arquivos.${NC}"
            log "${YELLOW}   -> Após resolver, finalize o processo ou, se preferir, use 'git stash drop' para descartar as alterações guardadas.${NC}"
            exit 1
        fi
    fi
    # =========================================================

    log "${YELLOW}🔍 Detectando arquivos grandes (>50MB) para Git LFS...${NC}"
    find . -type f -size +50M -not -path "./.git/*" -print0 | while IFS= read -r -d '' file; do
        if ! git lfs ls-files | grep -qF "./${file#./}"; then
            log "${GREEN}   + LFS: Rastreando novo arquivo grande: ${file#./}${NC}"
            git lfs track "${file#./}"
            git add .gitattributes
        fi
    done

    git add .

    log "${YELLOW}🔍 Verificando se novas pastas foram adicionadas como submódulos...${NC}"
    git diff --cached --raw | grep -E '160000 A' | cut -d'	' -f2 | while read -r submodule_path; do
        log "${YELLOW}⚠️  SUBMÓDULO DETECTADO: A pasta '${submodule_path}' foi adicionada incorretamente (contém uma pasta .git).${NC}"
        read -p "   -> Deseja convertê-la em uma pasta comum, adicionando seus arquivos ao projeto principal? (S/n): " choice
        choice=${choice:-S}

        if [[ "$choice" == "S" || "$choice" == "s" ]]; then
            log "${GREEN}   ✅ Convertendo '${submodule_path}' para um diretório comum...${NC}"
            git rm --cached "$submodule_path"
            rm -rf "$submodule_path/.git"
            git add "$submodule_path"
            log "${GREEN}   Conversão concluída. Os arquivos da pasta serão incluídos no commit.${NC}"
        else
            log "${YELLOW}   Operação cancelada. A pasta '${submodule_path}' será mantida como submódulo.${NC}"
        fi
    done

    if [ -z "$(git status --porcelain)" ]; then
        log "${GREEN}✅ Repositório local já está sincronizado. Nenhuma nova alteração para enviar.${NC}"
        exit 0
    fi

    log "${BLUE}✏️  Criando commit com as alterações locais...${NC}"
    git commit -m "feat(auto): Sincronização de arquivos em $(date +"%Y-%m-%d %H:%M")"

    log "${GREEN}🚀 Enviando alterações para o repositório remoto (push)...${NC}"
    git push origin main
fi

# Envia objetos LFS, se houver
log "${BLUE}📤 Enviando arquivos grandes via Git LFS (se houver)...${NC}"
git lfs push --all origin main

# --- RELATÓRIO FINAL ---
log "${GREEN}============================================${NC}"
log "${GREEN}   SINCRONIZAÇÃO CONCLUÍDA COM SUCESSO!     ${NC}"
log "${GREEN}============================================${NC}"
log "${YELLOW}Último commit enviado:${NC}"
git log -1 --pretty=format:"%h - %s (%cr)"
echo ""
log "${GREEN}============================================${NC}"

exit 0