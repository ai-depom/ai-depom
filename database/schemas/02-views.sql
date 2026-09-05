-- =====================================================
-- AI-DEPOM - BANCO DE DADOS POLICIAL
-- 02-views.sql - CRIAÇÃO DE VIEWS PARA CONSULTAS
-- =====================================================
-- Data: 04/09/2026
-- Versão: 1.0.0
-- Banco: Supabase (PostgreSQL 15+)
-- Descrição: Views para consultas otimizadas e relatórios
-- =====================================================

-- =====================================================
-- VIEW 1: vw_suspeito_ativos
-- =====================================================
-- Descrição: Suspeitos ativos (não deletados)
-- Uso: Consultas gerais, listagem de suspeitos
-- =====================================================

CREATE OR REPLACE VIEW public.vw_suspeito_ativos AS
SELECT 
    id_suspeito,
    nome_completo,
    apelido,
    cpf,
    rg,
    data_nascimento,
    sexo,
    raca,
    naturalidade,
    nacionalidade,
    cidade,
    uf,
    status_atual,
    nivel_periculosidade,
    data_cadastro,
    data_atualizacao,
    CASE 
        WHEN status_atual = 'PRESO' THEN '🔒 Preso'
        WHEN status_atual = 'PROCURADO' THEN '🔍 Procurado'
        WHEN status_atual = 'FORAGIDO' THEN '🏃 Foragido'
        WHEN status_atual = 'INVESTIGADO' THEN '🔎 Investigado'
        WHEN status_atual = 'CONDICIONAL' THEN '⚖️ Condicional'
        WHEN status_atual = 'LIBERADO' THEN '✅ Liberado'
        ELSE status_atual
    END AS status_label,
    CASE 
        WHEN nivel_periculosidade = 'EXTREMO' THEN '🔴 Extremo'
        WHEN nivel_periculosidade = 'ALTO' THEN '🟠 Alto'
        WHEN nivel_periculosidade = 'MEDIO' THEN '🟡 Médio'
        WHEN nivel_periculosidade = 'BAIXO' THEN '🟢 Baixo'
        ELSE nivel_periculosidade
    END AS periculosidade_label
FROM public.suspeito
WHERE deletado = FALSE;

-- =====================================================
-- VIEW 2: vw_suspeitos_com_mandados
-- =====================================================
-- Descrição: Suspeitos com mandados de prisão ativos
-- Uso: Alertas, dashboard, listagem de procurados
-- =====================================================

CREATE OR REPLACE VIEW public.vw_suspeitos_com_mandados AS
SELECT 
    s.id_suspeito,
    s.nome_completo,
    s.cpf,
    s.status_atual,
    s.nivel_periculosidade,
    s.cidade,
    s.uf,
    m.id_mandado,
    m.numero_mandado,
    m.tipo_mandado,
    m.juiz_nome,
    m.vara_tribunal,
    m.data_emissao,
    m.data_validade,
    m.prioridade,
    m.status AS status_mandado,
    m.descricao AS descricao_mandado,
    CASE 
        WHEN m.prioridade = 'URGENTE' THEN '🔴 URGENTE'
        WHEN m.prioridade = 'ALTA' THEN '🟠 ALTA'
        WHEN m.prioridade = 'NORMAL' THEN '🟡 NORMAL'
        ELSE m.prioridade
    END AS prioridade_label,
    CASE 
        WHEN m.data_validade < CURRENT_DATE THEN 'VENCIDO'
        WHEN m.data_validade < CURRENT_DATE + INTERVAL '7 days' THEN 'PRÓXIMO DO VENCIMENTO'
        ELSE 'VÁLIDO'
    END AS validade_status
FROM public.suspeito s
INNER JOIN public.mandado_prisao m ON s.id_suspeito = m.id_suspeito
WHERE s.deletado = FALSE 
  AND m.deletado = FALSE 
  AND m.status = 'ATIVO'
ORDER BY 
    CASE WHEN m.prioridade = 'URGENTE' THEN 1
         WHEN m.prioridade = 'ALTA' THEN 2
         ELSE 3 END,
    m.data_validade ASC;

-- =====================================================
-- VIEW 3: vw_investigacao_completa
-- =====================================================
-- Descrição: Detalhes completos das investigações
-- Uso: Relatórios, dashboard de investigações
-- =====================================================

CREATE OR REPLACE VIEW public.vw_investigacao_completa AS
SELECT 
    i.id_investigacao,
    i.numero_inquerito,
    i.tipo_crime,
    i.subtipo_crime,
    i.descricao,
    i.data_instauracao,
    i.data_conclusao,
    i.status,
    i.sigilosa,
    i.nivel_sigilo,
    d.nome AS delegacia_nome,
    d.sigla AS delegacia_sigla,
    p.nome_completo AS policial_responsavel,
    p.cargo AS policial_cargo,
    COUNT(DISTINCT e.id_suspeito) AS total_suspeitos,
    COUNT(DISTINCT o.id_ocorrencia) AS total_ocorrencias,
    COUNT(DISTINCT m.id_mandado) AS total_mandados,
    CASE 
        WHEN i.status = 'INICIADA' THEN '🟢 Iniciada'
        WHEN i.status = 'EM_ANDAMENTO' THEN '🟡 Em Andamento'
        WHEN i.status = 'SUSPENSA' THEN '🟠 Suspensa'
        WHEN i.status = 'CONCLUIDA' THEN '✅ Concluída'
        WHEN i.status = 'ARQUIVADA' THEN '📁 Arquivada'
        ELSE i.status
    END AS status_label,
    CASE 
        WHEN i.sigilosa = TRUE THEN '🔒 SIGILOSA'
        ELSE '📢 Pública'
    END AS sigilo_label
FROM public.investigacao i
LEFT JOIN public.delegacia d ON i.id_delegacia = d.id_delegacia
LEFT JOIN public.policial p ON i.id_policial_responsavel = p.id_policial
LEFT JOIN public.envolvimento e ON i.id_investigacao = e.id_investigacao AND e.ativo = TRUE
LEFT JOIN public.ocorrencia o ON i.id_investigacao = o.id_investigacao AND o.deletado = FALSE
LEFT JOIN public.mandado_prisao m ON i.id_investigacao = m.id_investigacao AND m.deletado = FALSE
WHERE i.deletado = FALSE
GROUP BY i.id_investigacao, d.nome, d.sigla, p.nome_completo, p.cargo;

-- =====================================================
-- VIEW 4: vw_estatisticas_diarias
-- =====================================================
-- Descrição: Estatísticas diárias do sistema
-- Uso: Dashboard, relatórios executivos
-- =====================================================

CREATE OR REPLACE VIEW public.vw_estatisticas_diarias AS
SELECT 
    CURRENT_DATE AS data,
    COUNT(DISTINCT s.id_suspeito) AS total_suspeitos,
    COUNT(DISTINCT s.id_suspeito) FILTER (WHERE s.status_atual = 'PRESO') AS total_presos,
    COUNT(DISTINCT s.id_suspeito) FILTER (WHERE s.status_atual = 'PROCURADO') AS total_procurados,
    COUNT(DISTINCT s.id_suspeito) FILTER (WHERE s.status_atual = 'FORAGIDO') AS total_foragidos,
    COUNT(DISTINCT s.id_suspeito) FILTER (WHERE s.nivel_periculosidade IN ('ALTO', 'EXTREMO')) AS total_alto_risco,
    COUNT(DISTINCT i.id_investigacao) FILTER (WHERE i.status IN ('INICIADA', 'EM_ANDAMENTO')) AS investigacoes_ativas,
    COUNT(DISTINCT m.id_mandado) FILTER (WHERE m.status = 'ATIVO') AS mandados_ativos,
    COUNT(DISTINCT m.id_mandado) FILTER (WHERE m.prioridade IN ('ALTA', 'URGENTE') AND m.status = 'ATIVO') AS mandados_prioritarios,
    COUNT(DISTINCT a.id_alerta) FILTER (WHERE a.lido = FALSE AND a.resolvido = FALSE) AS alertas_nao_lidos,
    COUNT(DISTINCT l.id_log) FILTER (WHERE l.data_hora > CURRENT_DATE) AS acessos_hoje
FROM public.suspeito s
LEFT JOIN public.investigacao i ON i.deletado = FALSE
LEFT JOIN public.mandado_prisao m ON m.deletado = FALSE
LEFT JOIN public.alerta_seguranca a ON a.deletado = FALSE
LEFT JOIN public.log_auditoria l ON TRUE
WHERE s.deletado = FALSE;

-- =====================================================
-- VIEW 5: vw_auditoria_acessos
-- =====================================================
-- Descrição: Log de acessos por usuário
-- Uso: Auditoria, segurança, relatórios de acesso
-- =====================================================

CREATE OR REPLACE VIEW public.vw_auditoria_acessos AS
SELECT 
    u.id_usuario,
    u.matricula,
    u.nome_completo,
    u.email,
    u.setor,
    p.nome AS perfil,
    COUNT(l.id_log) AS total_acessos,
    MAX(l.data_hora) AS ultimo_acesso,
    COUNT(l.id_log) FILTER (WHERE l.data_hora > CURRENT_TIMESTAMP - INTERVAL '24 hours') AS acessos_24h,
    COUNT(l.id_log) FILTER (WHERE l.sucesso = FALSE) AS tentativas_falhas,
    u.ativo,
    u.data_cadastro
FROM public.usuarios u
LEFT JOIN public.perfil_acesso p ON u.id_perfil_acesso = p.id_perfil
LEFT JOIN public.log_auditoria l ON u.id_usuario = l.id_usuario
WHERE u.deletado = FALSE
GROUP BY u.id_usuario, p.nome;

-- =====================================================
-- VIEW 6: vw_alertas_urgentes
-- =====================================================
-- Descrição: Alertas urgentes não resolvidos
-- Uso: Dashboard, notificações em tempo real
-- =====================================================

CREATE OR REPLACE VIEW public.vw_alertas_urgentes AS
SELECT 
    id_alerta,
    tipo_alerta,
    nivel_urgencia,
    id_entidade,
    tipo_entidade,
    mensagem,
    data_hora,
    CASE 
        WHEN nivel_urgencia = 'CRITICA' THEN '🔴 CRÍTICA'
        WHEN nivel_urgencia = 'ALTA' THEN '🟠 ALTA'
        WHEN nivel_urgencia = 'MEDIA' THEN '🟡 MÉDIA'
        WHEN nivel_urgencia = 'BAIXA' THEN '🟢 BAIXA'
        ELSE nivel_urgencia
    END AS urgencia_label,
    CASE 
        WHEN tipo_alerta = 'MANDADO' THEN '⚖️ Mandado'
        WHEN tipo_alerta = 'FUGA' THEN '🏃 Fuga'
        WHEN tipo_alerta = 'OCORRENCIA' THEN '📋 Ocorrência'
        WHEN tipo_alerta = 'SISTEMA' THEN '💻 Sistema'
        WHEN tipo_alerta = 'BIOMETRIA' THEN '🔐 Biometria'
        ELSE tipo_alerta
    END AS tipo_label,
    EXTRACT(HOUR FROM (NOW() - data_hora)) AS horas_desde
FROM public.alerta_seguranca
WHERE deletado = FALSE 
  AND lido = FALSE 
  AND resolvido = FALSE
  AND nivel_urgencia IN ('CRITICA', 'ALTA')
ORDER BY 
    CASE WHEN nivel_urgencia = 'CRITICA' THEN 1
         WHEN nivel_urgencia = 'ALTA' THEN 2
         ELSE 3 END,
    data_hora DESC;

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ VIEWS CRIADAS COM SUCESSO' ;
    RAISE NOTICE '📊 Total de views: 6' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '1. vw_suspeito_ativos' ;
    RAISE NOTICE '2. vw_suspeitos_com_mandados' ;
    RAISE NOTICE '3. vw_investigacao_completa' ;
    RAISE NOTICE '4. vw_estatisticas_diarias' ;
    RAISE NOTICE '5. vw_auditoria_acessos' ;
    RAISE NOTICE '6. vw_alertas_urgentes' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
