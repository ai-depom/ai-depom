-- =====================================================
-- AI-DEPOM - BANCO DE DADOS POLICIAL
-- 01-tables.sql - CRIAÇÃO DE TODAS AS TABELAS
-- =====================================================
-- Data: 04/09/2026
-- Versão: 1.0.0
-- Banco: Supabase (PostgreSQL 15+)
-- Descrição: Criação de todas as 13 tabelas do sistema
-- =====================================================

-- =====================================================
-- HABILITAR EXTENSÕES
-- =====================================================

-- UUID para chaves primárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Criptografia
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- 1. TABELA: PERFIL_ACESSO
-- =====================================================
-- Descrição: Define os perfis de acesso e suas permissões
-- Regras: Nível de acesso de 1 (básico) a 10 (master)
--          is_master = TRUE permite gerenciar usuários
-- =====================================================

CREATE TABLE public.perfil_acesso (
    id_perfil SERIAL PRIMARY KEY,
    nome VARCHAR(50) UNIQUE NOT NULL,
    descricao TEXT,
    nivel_acesso INTEGER NOT NULL CHECK (nivel_acesso BETWEEN 1 AND 10),
    is_master BOOLEAN DEFAULT FALSE,
    pode_gerenciar_usuarios BOOLEAN DEFAULT FALSE,
    permissoes JSONB NOT NULL,
    deletado BOOLEAN DEFAULT FALSE,
    data_cadastro TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. TABELA: DELEGACIA
-- =====================================================
-- Descrição: Cadastro de delegacias
-- =====================================================

CREATE TABLE public.delegacia (
    id_delegacia SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    sigla VARCHAR(20) UNIQUE NOT NULL,
    endereco TEXT NOT NULL,
    telefone VARCHAR(20),
    email VARCHAR(100),
    deletado BOOLEAN DEFAULT FALSE,
    data_cadastro TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3. TABELA: USUARIOS (ESTENDIDA DO AUTH)
-- =====================================================
-- Descrição: Usuários do sistema (vinculada ao auth.users)
-- Regras: id_usuario_cadastrador = quem criou o usuário
--          Apenas ADMINISTRADOR_MASTER pode cadastrar
-- =====================================================

CREATE TABLE public.usuarios (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    matricula VARCHAR(20) UNIQUE NOT NULL,
    nome_completo VARCHAR(200) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    setor VARCHAR(100) NOT NULL,
    id_perfil_acesso INTEGER NOT NULL DEFAULT 5 REFERENCES public.perfil_acesso(id_perfil),
    id_delegacia INTEGER REFERENCES public.delegacia(id_delegacia),
    ativo BOOLEAN DEFAULT TRUE,
    deletado BOOLEAN DEFAULT FALSE,
    data_cadastro TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_ultimo_acesso TIMESTAMP WITH TIME ZONE,
    primeiro_acesso BOOLEAN DEFAULT TRUE,
    id_usuario_cadastrador UUID REFERENCES public.usuarios(id),
    data_cadastro_usuario TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    tentativas_erradas INTEGER DEFAULT 0,
    bloqueado_ate TIMESTAMP WITH TIME ZONE
);

-- =====================================================
-- 4. TABELA: POLICIAL
-- =====================================================
-- Descrição: Policiais (servidores) que atuam no sistema
-- =====================================================

CREATE TABLE public.policial (
    id_policial SERIAL PRIMARY KEY,
    matricula VARCHAR(20) UNIQUE NOT NULL,
    nome_completo VARCHAR(200) NOT NULL,
    cargo VARCHAR(50) NOT NULL,
    id_delegacia INTEGER REFERENCES public.delegacia(id_delegacia),
    ativo BOOLEAN DEFAULT TRUE,
    deletado BOOLEAN DEFAULT FALSE,
    data_admissao DATE,
    data_desligamento DATE
);

-- =====================================================
-- 5. TABELA: SUSPEITO
-- =====================================================
-- Descrição: Cadastro completo de suspeitos (presos, procurados, etc)
-- Regras: Nunca deletar fisicamente (flag deletado)
--          Status_atual: INVESTIGADO, PRESO, FORAGIDO, PROCURADO, CONDICIONAL, LIBERADO
--          Nivel_periculosidade: BAIXO, MEDIO, ALTO, EXTREMO
-- =====================================================

CREATE TABLE public.suspeito (
    id_suspeito SERIAL PRIMARY KEY,
    nome_completo VARCHAR(200) NOT NULL,
    apelido VARCHAR(100),
    cpf VARCHAR(14) UNIQUE,
    rg VARCHAR(20) UNIQUE,
    orgao_expedidor VARCHAR(10),
    data_nascimento DATE,
    sexo CHAR(1) CHECK (sexo IN ('M', 'F', 'O')),
    raca VARCHAR(20),
    naturalidade VARCHAR(100),
    nacionalidade VARCHAR(50) DEFAULT 'Brasileira',
    nome_pai VARCHAR(200),
    nome_mae VARCHAR(200),
    cep VARCHAR(10),
    logradouro VARCHAR(200),
    numero VARCHAR(20),
    complemento VARCHAR(100),
    bairro VARCHAR(100),
    cidade VARCHAR(100),
    uf CHAR(2),
    pais VARCHAR(50) DEFAULT 'Brasil',
    altura DECIMAL(3,2),
    peso DECIMAL(5,2),
    cor_olhos VARCHAR(20),
    cor_cabelo VARCHAR(20),
    cor_pele VARCHAR(20),
    sinais_particulares TEXT,
    tattoo_descricao TEXT,
    status_atual VARCHAR(20) NOT NULL DEFAULT 'INVESTIGADO' 
        CHECK (status_atual IN ('INVESTIGADO', 'PRESO', 'FORAGIDO', 'PROCURADO', 'CONDICIONAL', 'LIBERADO')),
    nivel_periculosidade VARCHAR(15) DEFAULT 'BAIXO'
        CHECK (nivel_periculosidade IN ('BAIXO', 'MEDIO', 'ALTO', 'EXTREMO')),
    modus_operandi TEXT,
    organizacao_criminal VARCHAR(100),
    envolvimento_drogas BOOLEAN DEFAULT FALSE,
    posse_arma BOOLEAN DEFAULT FALSE,
    foto_hash VARCHAR(255),
    biometria_hash VARCHAR(255),
    deletado BOOLEAN DEFAULT FALSE,
    data_cadastro TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_atualizacao TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_falecimento DATE,
    observacoes TEXT,
    id_usuario_cadastro UUID REFERENCES public.usuarios(id),
    id_usuario_atualizacao UUID REFERENCES public.usuarios(id),
    data_ultima_consulta TIMESTAMP WITH TIME ZONE,
    quantidade_consultas INTEGER DEFAULT 0
);

-- =====================================================
-- 6. TABELA: INVESTIGACAO
-- =====================================================
-- Descrição: Inquéritos e investigações policiais
-- Regras: Sigilosa: dados sigilosos requerem nível de acesso maior
--          Status: INICIADA, EM_ANDAMENTO, SUSPENSA, CONCLUIDA, ARQUIVADA
-- =====================================================

CREATE TABLE public.investigacao (
    id_investigacao SERIAL PRIMARY KEY,
    numero_inquerito VARCHAR(30) UNIQUE NOT NULL,
    tipo_crime VARCHAR(100) NOT NULL,
    subtipo_crime VARCHAR(100),
    descricao TEXT NOT NULL,
    data_instauracao DATE NOT NULL,
    data_conclusao DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'INICIADA'
        CHECK (status IN ('INICIADA', 'EM_ANDAMENTO', 'SUSPENSA', 'CONCLUIDA', 'ARQUIVADA')),
    sigilosa BOOLEAN DEFAULT FALSE,
    nivel_sigilo INTEGER DEFAULT 1 CHECK (nivel_sigilo BETWEEN 1 AND 5),
    id_delegacia INTEGER REFERENCES public.delegacia(id_delegacia),
    id_policial_responsavel INTEGER REFERENCES public.policial(id_policial),
    id_usuario_cadastro UUID REFERENCES public.usuarios(id),
    deletado BOOLEAN DEFAULT FALSE,
    data_cadastro TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_atualizacao TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    observacoes TEXT,
    valor_dano_estimado DECIMAL(15,2)
);

-- =====================================================
-- 7. TABELA: ENVOLVIMENTO
-- =====================================================
-- Descrição: Relacionamento entre suspeitos e investigações
-- Regras: Papel: SUSPEITO, TESTEMUNHA, VITIMA, DELATOR
-- =====================================================

CREATE TABLE public.envolvimento (
    id_envolvimento SERIAL PRIMARY KEY,
    id_suspeito INTEGER NOT NULL REFERENCES public.suspeito(id_suspeito),
    id_investigacao INTEGER NOT NULL REFERENCES public.investigacao(id_investigacao),
    papel VARCHAR(30) NOT NULL CHECK (papel IN ('SUSPEITO', 'TESTEMUNHA', 'VITIMA', 'DELATOR')),
    data_inclusao TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_remocao TIMESTAMP WITH TIME ZONE,
    ativo BOOLEAN DEFAULT TRUE,
    observacoes TEXT,
    UNIQUE(id_suspeito, id_investigacao, papel)
);

-- =====================================================
-- 8. TABELA: OCORRENCIA
-- =====================================================
-- Descrição: Boletins de ocorrência
-- =====================================================

CREATE TABLE public.ocorrencia (
    id_ocorrencia SERIAL PRIMARY KEY,
    numero_boletim VARCHAR(30) UNIQUE NOT NULL,
    id_investigacao INTEGER REFERENCES public.investigacao(id_investigacao),
    data_hora TIMESTAMP WITH TIME ZONE NOT NULL,
    localizacao TEXT NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    tipo_ocorrencia VARCHAR(50) NOT NULL,
    descricao TEXT NOT NULL,
    gravidade VARCHAR(15) DEFAULT 'MEDIA'
        CHECK (gravidade IN ('BAIXA', 'MEDIA', 'ALTA', 'CRITICA')),
    id_usuario_cadastro UUID REFERENCES public.usuarios(id),
    deletado BOOLEAN DEFAULT FALSE,
    data_cadastro TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_atualizacao TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 9. TABELA: MANDADO_PRISAO
-- =====================================================
-- Descrição: Mandados de prisão, busca e apreensão, condução coercitiva
-- Regras: Prioridade: NORMAL, ALTA, URGENTE
--          Status: ATIVO, CUMPRIDO, VENCIDO, CANCELADO, SUSPENSO
-- =====================================================

CREATE TABLE public.mandado_prisao (
    id_mandado SERIAL PRIMARY KEY,
    numero_mandado VARCHAR(30) UNIQUE NOT NULL,
    id_suspeito INTEGER NOT NULL REFERENCES public.suspeito(id_suspeito),
    id_investigacao INTEGER REFERENCES public.investigacao(id_investigacao),
    tipo_mandado VARCHAR(30) NOT NULL CHECK (tipo_mandado IN ('PRISAO', 'BUSCA_APREENSAO', 'CONDUCAO_COERCITIVA')),
    juiz_nome VARCHAR(200) NOT NULL,
    juiz_matricula VARCHAR(30),
    vara_tribunal VARCHAR(100) NOT NULL,
    processo_numero VARCHAR(30),
    data_emissao DATE NOT NULL,
    data_validade DATE,
    data_cumprimento DATE,
    prioridade VARCHAR(15) DEFAULT 'NORMAL'
        CHECK (prioridade IN ('NORMAL', 'ALTA', 'URGENTE')),
    status VARCHAR(20) DEFAULT 'ATIVO'
        CHECK (status IN ('ATIVO', 'CUMPRIDO', 'VENCIDO', 'CANCELADO', 'SUSPENSO')),
    descricao TEXT NOT NULL,
    documento_hash VARCHAR(255),
    documento_caminho VARCHAR(500),
    id_usuario_emissao UUID REFERENCES public.usuarios(id),
    id_usuario_cumprimento UUID REFERENCES public.usuarios(id),
    deletado BOOLEAN DEFAULT FALSE,
    data_cadastro TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_atualizacao TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    observacoes TEXT
);

-- =====================================================
-- 10. TABELA: ARQUIVO_MIDIA
-- =====================================================
-- Descrição: Armazenamento de fotos, vídeos, áudios e documentos
-- Regras: Tipo: FOTO, VIDEO, AUDIO, DOCUMENTO, BIOMETRIA
--          Nível de segurança: PUBLICO, RESTRITO, SIGILOSO, ULTRASSECRETO
-- =====================================================

CREATE TABLE public.arquivo_midia (
    id_arquivo SERIAL PRIMARY KEY,
    id_entidade INTEGER NOT NULL,
    tipo_entidade VARCHAR(30) NOT NULL,
    nome_original VARCHAR(255) NOT NULL,
    nome_seguro VARCHAR(255) NOT NULL,
    tipo_midia VARCHAR(20) NOT NULL CHECK (tipo_midia IN ('FOTO', 'VIDEO', 'AUDIO', 'DOCUMENTO', 'BIOMETRIA')),
    formato VARCHAR(10) NOT NULL,
    tamanho_bytes BIGINT NOT NULL,
    hash_sha256 VARCHAR(64) NOT NULL,
    caminho_fisico VARCHAR(500) NOT NULL,
    metadata JSONB,
    nivel_seguranca VARCHAR(20) DEFAULT 'PUBLICO'
        CHECK (nivel_seguranca IN ('PUBLICO', 'RESTRITO', 'SIGILOSO', 'ULTRASSECRETO')),
    status VARCHAR(20) DEFAULT 'ATIVO'
        CHECK (status IN ('ATIVO', 'ARQUIVADO', 'EM_ANALISE')),
    id_usuario_upload UUID REFERENCES public.usuarios(id),
    data_upload TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_atualizacao TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assinatura_digital TEXT,
    deletado BOOLEAN DEFAULT FALSE,
    observacoes TEXT
);

-- =====================================================
-- 11. TABELA: LOG_AUDITORIA
-- =====================================================
-- Descrição: Registro de todas as ações do sistema
-- =====================================================

CREATE TABLE public.log_auditoria (
    id_log SERIAL PRIMARY KEY,
    id_usuario UUID REFERENCES public.usuarios(id),
    acao VARCHAR(50) NOT NULL,
    tabela VARCHAR(50) NOT NULL,
    id_registro INTEGER,
    dados_anteriores JSONB,
    dados_novos JSONB,
    query_executada TEXT,
    ip_origem VARCHAR(45) NOT NULL,
    user_agent TEXT,
    data_hora TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sucesso BOOLEAN DEFAULT TRUE,
    mensagem_erro TEXT
);

-- =====================================================
-- 12. TABELA: ALERTA_SEGURANCA
-- =====================================================
-- Descrição: Alertas de segurança (mandados, fugas, etc)
-- =====================================================

CREATE TABLE public.alerta_seguranca (
    id_alerta SERIAL PRIMARY KEY,
    tipo_alerta VARCHAR(30) NOT NULL CHECK (tipo_alerta IN ('MANDADO', 'FUGA', 'OCORRENCIA', 'SISTEMA', 'BIOMETRIA')),
    nivel_urgencia VARCHAR(15) NOT NULL CHECK (nivel_urgencia IN ('BAIXA', 'MEDIA', 'ALTA', 'CRITICA')),
    id_entidade INTEGER,
    tipo_entidade VARCHAR(30),
    mensagem TEXT NOT NULL,
    data_hora TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    lido BOOLEAN DEFAULT FALSE,
    data_leitura TIMESTAMP WITH TIME ZONE,
    id_usuario_leitura UUID REFERENCES public.usuarios(id),
    resolvido BOOLEAN DEFAULT FALSE,
    data_resolucao TIMESTAMP WITH TIME ZONE,
    id_usuario_resolucao UUID REFERENCES public.usuarios(id),
    deletado BOOLEAN DEFAULT FALSE
);

-- =====================================================
-- 13. TABELA: LOG_CADASTRO_USUARIO
-- =====================================================
-- Descrição: Log específico de cadastro de usuários
-- =====================================================

CREATE TABLE public.log_cadastro_usuario (
    id_log SERIAL PRIMARY KEY,
    id_usuario_cadastrador UUID REFERENCES public.usuarios(id),
    id_usuario_cadastrado UUID REFERENCES public.usuarios(id),
    acao VARCHAR(20) NOT NULL CHECK (acao IN ('CADASTRO', 'ATUALIZACAO', 'DESATIVACAO', 'REATIVACAO', 'ALTERACAO_PERFIL')),
    dados_anteriores JSONB,
    dados_novos JSONB,
    ip_origem VARCHAR(45) NOT NULL,
    data_hora TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sucesso BOOLEAN DEFAULT TRUE,
    mensagem_erro TEXT
);

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ TABELAS CRIADAS COM SUCESSO' ;
    RAISE NOTICE '📊 Total de tabelas: 13' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '1. perfil_acesso' ;
    RAISE NOTICE '2. delegacia' ;
    RAISE NOTICE '3. usuarios' ;
    RAISE NOTICE '4. policial' ;
    RAISE NOTICE '5. suspeito' ;
    RAISE NOTICE '6. investigacao' ;
    RAISE NOTICE '7. envolvimento' ;
    RAISE NOTICE '8. ocorrencia' ;
    RAISE NOTICE '9. mandado_prisao' ;
    RAISE NOTICE '10. arquivo_midia' ;
    RAISE NOTICE '11. log_auditoria' ;
    RAISE NOTICE '12. alerta_seguranca' ;
    RAISE NOTICE '13. log_cadastro_usuario' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
