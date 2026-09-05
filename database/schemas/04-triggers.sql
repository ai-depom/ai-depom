-- =====================================================
-- AI-DEPOM - BANCO DE DADOS POLICIAL
-- 04-triggers.sql - TRIGGERS DE SEGURANÇA E AUDITORIA
-- =====================================================
-- Data: 04/09/2026
-- Versão: 1.0.0
-- Banco: Supabase (PostgreSQL 15+)
-- Descrição: Triggers para segurança, auditoria e integridade
-- =====================================================

-- =====================================================
-- TRIGGER 1: prevent_delete_suspeito
-- =====================================================
-- Descrição: Impede DELETE físico na tabela suspeito
-- Evento: BEFORE DELETE
-- Ação: Lança exceção orientando usar exclusão lógica
-- =====================================================

CREATE OR REPLACE TRIGGER prevent_delete_suspeito
BEFORE DELETE ON public.suspeito
FOR EACH ROW
EXECUTE FUNCTION public.prevent_physical_delete();

-- =====================================================
-- TRIGGER 2: prevent_delete_investigacao
-- =====================================================
-- Descrição: Impede DELETE físico na tabela investigacao
-- Evento: BEFORE DELETE
-- Ação: Lança exceção orientando usar exclusão lógica
-- =====================================================

CREATE OR REPLACE TRIGGER prevent_delete_investigacao
BEFORE DELETE ON public.investigacao
FOR EACH ROW
EXECUTE FUNCTION public.prevent_physical_delete();

-- =====================================================
-- TRIGGER 3: prevent_delete_mandado
-- =====================================================
-- Descrição: Impede DELETE físico na tabela mandado_prisao
-- Evento: BEFORE DELETE
-- Ação: Lança exceção orientando usar exclusão lógica
-- =====================================================

CREATE OR REPLACE TRIGGER prevent_delete_mandado
BEFORE DELETE ON public.mandado_prisao
FOR EACH ROW
EXECUTE FUNCTION public.prevent_physical_delete();

-- =====================================================
-- TRIGGER 4: prevent_delete_ocorrencia
-- =====================================================
-- Descrição: Impede DELETE físico na tabela ocorrencia
-- Evento: BEFORE DELETE
-- Ação: Lança exceção orientando usar exclusão lógica
-- =====================================================

CREATE OR REPLACE TRIGGER prevent_delete_ocorrencia
BEFORE DELETE ON public.ocorrencia
FOR EACH ROW
EXECUTE FUNCTION public.prevent_physical_delete();

-- =====================================================
-- TRIGGER 5: prevent_delete_arquivo
-- =====================================================
-- Descrição: Impede DELETE físico na tabela arquivo_midia
-- Evento: BEFORE DELETE
-- Ação: Lança exceção orientando usar exclusão lógica
-- =====================================================

CREATE OR REPLACE TRIGGER prevent_delete_arquivo
BEFORE DELETE ON public.arquivo_midia
FOR EACH ROW
EXECUTE FUNCTION public.prevent_physical_delete();

-- =====================================================
-- TRIGGER 6: prevent_delete_usuario
-- =====================================================
-- Descrição: Impede DELETE físico na tabela usuarios
-- Evento: BEFORE DELETE
-- Ação: Lança exceção orientando usar exclusão lógica
-- =====================================================

CREATE OR REPLACE TRIGGER prevent_delete_usuario
BEFORE DELETE ON public.usuarios
FOR EACH ROW
EXECUTE FUNCTION public.prevent_physical_delete();

-- =====================================================
-- TRIGGER 7: prevent_delete_policial
-- =====================================================
-- Descrição: Impede DELETE físico na tabela policial
-- Evento: BEFORE DELETE
-- Ação: Lança exceção orientando usar exclusão lógica
-- =====================================================

CREATE OR REPLACE TRIGGER prevent_delete_policial
BEFORE DELETE ON public.policial
FOR EACH ROW
EXECUTE FUNCTION public.prevent_physical_delete();

-- =====================================================
-- TRIGGER 8: log_suspeito_insert (OPCIONAL - DESATIVADO POR PADRÃO)
-- =====================================================
-- Descrição: Registra INSERT na tabela suspeito
-- Evento: AFTER INSERT
-- Ação: Insere registro em log_auditoria
-- NOTA: Descomente para ativar
-- =====================================================

-- CREATE OR REPLACE TRIGGER log_suspeito_insert
-- AFTER INSERT ON public.suspeito
-- FOR EACH ROW
-- EXECUTE FUNCTION public.log_auditoria_insert();

-- =====================================================
-- TRIGGER 9: log_investigacao_insert (OPCIONAL - DESATIVADO POR PADRÃO)
-- =====================================================
-- Descrição: Registra INSERT na tabela investigacao
-- Evento: AFTER INSERT
-- Ação: Insere registro em log_auditoria
-- NOTA: Descomente para ativar
-- =====================================================

-- CREATE OR REPLACE TRIGGER log_investigacao_insert
-- AFTER INSERT ON public.investigacao
-- FOR EACH ROW
-- EXECUTE FUNCTION public.log_auditoria_insert();

-- =====================================================
-- TRIGGER 10: log_suspeito_update (OPCIONAL - DESATIVADO POR PADRÃO)
-- =====================================================
-- Descrição: Registra UPDATE na tabela suspeito
-- Evento: AFTER UPDATE
-- Ação: Insere registro em log_auditoria
-- NOTA: Descomente para ativar
-- =====================================================

-- CREATE OR REPLACE TRIGGER log_suspeito_update
-- AFTER UPDATE ON public.suspeito
-- FOR EACH ROW
-- EXECUTE FUNCTION public.log_auditoria_update();

-- =====================================================
-- MENSAGEM DE CONCLUSÃO
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '✅ TRIGGERS CRIADOS COM SUCESSO' ;
    RAISE NOTICE '📊 Total de triggers: 7 (ativos)' ;
    RAISE NOTICE '📅 Data: %', NOW() ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE 'TRIGGERS ATIVOS:' ;
    RAISE NOTICE '1. prevent_delete_suspeito' ;
    RAISE NOTICE '2. prevent_delete_investigacao' ;
    RAISE NOTICE '3. prevent_delete_mandado' ;
    RAISE NOTICE '4. prevent_delete_ocorrencia' ;
    RAISE NOTICE '5. prevent_delete_arquivo' ;
    RAISE NOTICE '6. prevent_delete_usuario' ;
    RAISE NOTICE '7. prevent_delete_policial' ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE 'TRIGGERS OPCIONAIS (DESATIVADOS):' ;
    RAISE NOTICE '8. log_suspeito_insert' ;
    RAISE NOTICE '9. log_investigacao_insert' ;
    RAISE NOTICE '10. log_suspeito_update' ;
    RAISE NOTICE '===========================================' ;
    RAISE NOTICE '🔒 Proteção contra DELETE físico: ATIVA' ;
    RAISE NOTICE '📋 Auditoria automática: OPCIONAL' ;
    RAISE NOTICE '===========================================' ;
END;
$$;
