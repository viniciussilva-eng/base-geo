#!/bin/bash

# ==================================================
# Script de sincronização GitHub robusto com relatório
# Versão corrigida e otimizada
# ==================================================

# --- Configuração ---
# Cores para o output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Funções Auxiliares ---
# Função para logar mensagens com timestamp
log() {
    echo -e "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# --- Início do Script ---
log "${BLUE}============================================${NC}"
log "${BLUE}  INICIANDO SINCRONIZAÇÃO COM O REPOSITÓRIO   ${NC}"
log "${BLUE}============================================${NC}"

# Definições do Projeto
PROJETO_DIR=$(pwd)
REPO_URL="https://github.com/viniciussilva-eng/base-geo.git"

log "${YELLOW}📁 Projeto: $PROJETO_DIR${NC}"
log "${YELLOW}🌐 Repositório remoto: $REPO_URL${NC}"

# Configurar o Git para confiar neste diretório (evita erros de propriedade)
git config --global --add safe.directory "$PROJETO_DIR"

# 1. INICIALIZAÇÃO (se necessário)
# Garante que o diretório é um repositório Git
if [ ! -d ".git" ]; then
    log "${GREEN}✅ Repositório não encontrado. Inicializando um novo...${NC}"
    git init
    git branch -M main
fi

# 2. CONFIGURAÇÃO DO REMOTO
# Garante que o 'origin' aponta para a URL correta
log "${BLUE}🔧 Verificando e configurando o repositório remoto...${NC}"
git remote remove origin &>/dev/null
git remote add origin "$REPO_URL"
log "${GREEN}✅ Remoto 'origin' configurado para $REPO_URL${NC}"

# 3. CONFIGURAÇÃO DE CREDENCIAIS (Recomendação de segurança)
# Recomenda-se 'cache' para segurança em vez de 'store'
# O cache mantém a senha na memória por um tempo (padrão: 15 minutos)
git config --global credential.helper 'cache --timeout=3600' # Timeout de 1 hora
log "${GREEN}✅ Credential helper configurado para 'cache' (mais seguro).${NC}"

# 4. SINCRONIZAÇÃO COM O REMOTO (PULL)
# Baixa as alterações do remoto ANTES de fazer qualquer commit local
log "${BLUE}🔄 Puxando alterações do repositório remoto (git pull)...${NC}"
if ! git pull origin main --rebase; then
    log "${RED}❌ Falha ao executar 'git pull'. Conflitos podem existir. Abortando.${NC}"
    log "${YELLOW}💡 Resolva os conflitos manualmente com 'git status' e tente novamente.${NC}"
    exit 1
fi
log "${GREEN}✅ Repositório local sincronizado com o remoto.${NC}"

# 5. GIT LFS (Large File Storage)
# Instala e busca por arquivos grandes para rastreamento
git lfs install
log "${YELLOW}🔍 Detectando arquivos grandes (>50MB) para rastreamento com Git LFS...${NC}"
ARQUIVOS_GRANDES=$(find . -type f -size +50M -not -path "./.git/*")
if [ -z "$ARQUIVOS_GRANDES" ]; then
    log "${GREEN}Nenhum arquivo novo com mais de 50MB detectado.${NC}"
else
    log "${YELLOW}Arquivos grandes detectados. Rastreando com LFS:${NC}"
    echo "$ARQUIVOS_GRANDES"
    # Adiciona cada arquivo ao rastreamento do LFS
    echo "$ARQUIVOS_GRANDES" | while read -r arquivo; do
        git lfs track "${arquivo#./}"
    done
    # Adiciona o arquivo .gitattributes ao stage para registrar as regras de LFS
    git add .gitattributes
fi

# 6. VERIFICAÇÃO DE ALTERAÇÕES LOCAIS
# Verifica se há algo para commitar antes de prosseguir
if [ -z "$(git status --porcelain)" ]; then
    log "${GREEN}✅ Não há alterações locais para sincronizar. Trabalho concluído.${NC}"
    exit 0
fi

# 7. COMMIT DAS ALTERAÇÕES
log "${BLUE}📦 Adicionando todos os arquivos modificados (git add .)...${NC}"
git add .

log "${BLUE}✏️  Criando commit com as alterações locais...${NC}"
COMMIT_MSG="sinc(auto): Atualização de arquivos em $(date +"%Y-%m-%d %H:%M:%S")"
git commit -m "$COMMIT_MSG"

# 8. PUSH PARA O REMOTO
# Envia os commits e, em seguida, os objetos LFS
log "${BLUE}🚀 Enviando alterações para o repositório remoto (git push)...${NC}"
if ! git push origin main; then
    log "${RED}❌ Falha ao executar 'git push'. Verifique a conexão e permissões.${NC}"
    exit 1
fi

# O comando 'git lfs push' é frequentemente redundante se o hook pre-push estiver instalado,
# mas executá-lo explicitamente garante o envio dos arquivos grandes.
log "${BLUE}📤 Enviando arquivos grandes via Git LFS...${NC}"
git lfs push --all origin main

# --- Relatório Final ---
log "${GREEN}============================================${NC}"
log "${GREEN}   RELATÓRIO DE SINCRONIZAÇÃO FINAL         ${NC}"
log "${GREEN}============================================${NC}"
log "${YELLOW}Último commit enviado:${NC}"
git log -1 --pretty=%B
log "${YELLOW}Arquivos rastreados pelo Git LFS:${NC}"
git lfs ls-files
log "${GREEN}============================================${NC}"
log "${GREEN}   SINCRONIZAÇÃO CONCLUÍDA COM SUCESSO!     ${NC}"
log "${GREEN}============================================${NC}"

exit 0
