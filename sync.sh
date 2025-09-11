#!/bin/bash

# ====================================================================
# Script de Sincronização com GitHub v5.5 (Interativo e Robusto)
#
# Lógica de stash corrigida para evitar falsos positivos de conflito.
# Usa detecção precisa de alterações para decidir se o stash é necessário.
# Verifica se um stash existe antes de tentar restaurá-lo.
#
# Uso:
#    ./sync.sh       -> Executa o modo de sincronização padrão e seguro.
#    ./sync.sh force -> Executa o modo forçado (espelho local -> remoto).
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
log "${BLUE}  INICIANDO SCRIPT DE SINCRONIZAÇÃO v5.5      ${NC}"
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
    # (O modo forçado permanece o mesmo)
    log "${RED}🚨 MODO FORÇADO ATIVADO! 🚨${NC}"
    log "${YELLOW}Este modo fará o repositório remoto ser um ESPELHO EXATO da sua pasta local.${NC}"
    log "${RED}AVISO: Commits existentes no remoto que não estão no local serão perdidos.${NC}"
    read -p "Você tem certeza que deseja continuar? (s/N): " confirm < /dev/tty
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then log "${GREEN}Operação cancelada pelo usuário.${NC}" && exit 0; fi

    log "${BLUE}➕ Adicionando todos os arquivos ao stage...${NC}"
    git add .
    log "${BLUE}✏️  Criando commit de espelhamento...${NC}"
    git commit -m "refactor(force): Sincronização forçada para espelhar estado local em $(date +"%Y-%m-%d %H:%M")" || true
    
    log "${BLUE}📤 Enviando arquivos grandes via Git LFS (se houver)...${NC}"
    git lfs push --all origin main
    log "${RED}🚀 Executando PUSH FORÇADO para 'main'...${NC}"
    git push --force origin main

else
    # ==================== MODO PADRÃO (SEGURO) ====================
    log "${GREEN}▶️  Executando em modo de sincronização padrão (seguro).${NC}"

    # ==============================================================================
    # 🌟 LÓGICA DE STASH CORRIGIDA 🌟
    # ==============================================================================
    STASH_CREATED=false
    # Usa `git diff-index` para verificar APENAS alterações em arquivos rastreados,
    # que é o comportamento padrão do `git stash`.
    if ! git diff-index --quiet HEAD --; then
        log "${YELLOW}⚠️  Detectadas alterações em arquivos rastreados. Guardando-as temporariamente...${NC}"
        git stash push -m "sync.sh: Stash automático antes da sincronização"
        STASH_CREATED=true
        log "${GREEN}    ✅ Alterações guardadas com sucesso.${NC}"
    else
        log "${GREEN}✅ Nenhuma alteração em arquivos rastreados. Nenhum stash necessário.${NC}"
    fi
    
    log "${BLUE}🔄 Sincronizando com o repositório remoto (pull --rebase)...${NC}"
    git pull --rebase origin main

    log "${BLUE}🔄 Atualizando submódulos (se houver) com as versões remotas...${NC}"
    git submodule update --remote --merge

    # Lógica de restauração mais segura
    if [ "$STASH_CREATED" = true ]; then
        log "${BLUE}🔄 Restaurando suas alterações locais que foram guardadas...${NC}"
        # Tenta aplicar o stash. Se falhar, é um conflito real.
        if ! git stash pop; then
            log "${RED}🚨 CONFLITO REAL AO RESTAURAR! 🚨 Não foi possível reaplicar suas alterações automaticamente.${NC}"
            log "${YELLOW}    -> Suas alterações ainda estão salvas no stash. Resolva os conflitos indicados nos arquivos.${NC}"
            exit 1
        else
            log "${GREEN}    ✅ Alterações restauradas com sucesso.${NC}"
        fi
    fi
    # ==============================================================================
    
    log "${YELLOW}🔍 Verificando arquivos e diretórios não rastreados...${NC}"
    git ls-files --others --exclude-standard | while read -r untracked_path; do
        log "${YELLOW}❓ Encontrado item não rastreado: '${untracked_path}'. O que fazer?${NC}"
        echo -e "   1. ${RED}Ignorar permanentemente${NC} (adicionar ao .gitignore)"
        echo -e "   2. ${BLUE}Rastrear com Git LFS${NC} (para dados e arquivos grandes)"
        echo -e "   3. ${GREEN}Rastrear com Git Normal${NC} (para código-fonte e arquivos pequenos)"
        echo -e "   4. Pular (ignorar por agora, não fazer nada)"
        read -p "   Sua escolha [1-4, padrão=4]: " choice < /dev/tty
        case "${choice:-4}" in
            1)
                log "   -> Adicionando '${untracked_path}' ao .gitignore..."
                [[ -n $(tail -c1 .gitignore 2>/dev/null) ]] && echo "" >> .gitignore
                echo "${untracked_path}" >> .gitignore; git add .gitignore
                log "${GREEN}   ✅ '${untracked_path}' adicionado ao .gitignore.${NC}"
                ;;
            2)
                log "   -> Rastreando '${untracked_path}' com Git LFS..."
                git lfs track "${untracked_path}"; git add .gitattributes; git add "${untracked_path}"
                log "${GREEN}   ✅ '${untracked_path}' agora é rastreado pelo LFS.${NC}"
                ;;
            3)
                log "   -> Rastreando '${untracked_path}' com Git normal..."
                git add "${untracked_path}"
                log "${GREEN}   ✅ '${untracked_path}' adicionado normalmente.${NC}"
                ;;
            *)
                log "${YELLOW}   -> '${untracked_path}' será ignorado nesta sincronização.${NC}"
                ;;
        esac; echo "" 
    done

    git add .
    # (Lógica de submódulo continua a mesma)

    if [ -z "$(git status --porcelain)" ]; then
        log "${GREEN}✅ Repositório local já está sincronizado. Nenhuma nova alteração para enviar.${NC}"
        exit 0
    fi

    log "${BLUE}✏️  Criando commit com as alterações locais...${NC}"
    git commit -m "feat(auto): Sincronização de arquivos em $(date +"%Y-%m-%d %H:%M")"

    log "${BLUE}📤 Enviando arquivos grandes via Git LFS (se houver)...${NC}"
    git lfs push --all origin main

    log "${GREEN}🚀 Enviando alterações para o repositório remoto (push)...${NC}"
    git push origin main
fi

# --- RELATÓRIO FINAL ---
log "${GREEN}============================================${NC}"
log "${GREEN}    SINCRONIZAÇÃO CONCLUÍDA COM SUCESSO!      ${NC}"
log "${GREEN}============================================${NC}"
log "${YELLOW}Último commit enviado:${NC}"
git log -1 --pretty=format:"%h - %s (%cr)"
echo ""
log "${GREEN}============================================${NC}"

exit 0