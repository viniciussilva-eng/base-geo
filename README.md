# base-geo
# Projeto Base de Geoprocessamento com Sincronização Automatizada

Este é um repositório modelo (template) projetado para ser o ponto de partida para projetos de geoprocessamento que exigem um versionamento robusto e seguro de dados e códigos.

O objetivo é garantir a integridade, a rastreabilidade e a segurança dos dados geoespaciais, que são o ativo principal do projeto.

---

## O Problema que Este Projeto Resolve

Trabalhar com dados geoespaciais (shapefiles, GeoPackages, GeoTIFFs) em sistemas de controle de versão como o Git apresenta desafios únicos:

- **Arquivos Grandes e Binários**: Dados geoespaciais frequentemente excedem os limites práticos do Git, resultando em repositórios lentos e inchados.
- **Perda de Histórico Eficiente**: Como os arquivos são binários, o Git não consegue armazenar apenas as "diferenças", salvando cópias completas a cada alteração.
- **Fluxo de Sincronização Complexo**: O processo manual para sincronizar código, dados grandes (LFS) e alterações remotas é complexo e propenso a erros que podem levar à perda de trabalho.

## A Solução Proposta

Este projeto implementa um fluxo de trabalho robusto que resolve os problemas acima através de três pilares:

1.  **Git LFS (Large File Storage)**: Para versionar os dados pesados de forma eficiente, mantendo o repositório principal leve e rápido.
2.  **Script `sync.sh`**: Uma ferramenta de automação que executa a sequência correta de comandos de sincronização, eliminando o risco de erro humano e garantindo que tanto o código quanto os dados LFS sejam enviados corretamente.
3.  **Estrutura de Pastas Padronizada**: Uma organização lógica dos diretórios que separa dados brutos, dados processados, análises e scripts, facilitando a manutenção e a reprodutibilidade do trabalho.

---

## 📂 Estrutura de Pastas Recomendada

Para manter a organização, recomenda-se a seguinte estrutura de diretórios:
