// supabase/functions/consulta-bnmp/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Variáveis de ambiente configuradas no Supabase
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const BNMP_API_URL = 'https://api-bnmp-integracao.stg.cloud.pje.jus.br' // URL de homologação
const BNMP_TOKEN = Deno.env.get('BNMP_TOKEN')! // Token JWT fixo fornecido pelo CNJ

serve(async (req) => {
  // Cria um cliente Supabase com permissões de serviço para ignorar RLS
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false }
  })

  try {
    // 1. Busca todos os suspeitos com CPF e que não foram deletados
    const { data: suspeitos, error: suspeitosError } = await supabase
      .from('suspeito')
      .select('id_suspeito, nome_completo, cpf')
      .not('cpf', 'is', null)
      .eq('deletado', false)

    if (suspeitosError) throw suspeitosError
    if (!suspeitos || suspeitos.length === 0) {
      return new Response(JSON.stringify({ message: 'Nenhum suspeito com CPF encontrado.' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    console.log(`Iniciando consulta para ${suspeitos.length} suspeitos.`)

    // 2. Itera sobre cada suspeito para consultar o BNMP
    const resultados = []
    for (const suspeito of suspeitos) {
      const cpfLimpo = suspeito.cpf.replace(/\D/g, '') // Remove máscara do CPF
      if (cpfLimpo.length !== 11) {
        console.warn(`CPF inválido para o suspeito ${suspeito.nome_completo}: ${suspeito.cpf}`)
        continue
      }

      // 3. Chama a API do BNMP
      // Endpoint de exemplo para consulta por CPF. Pode ser necessário ajustar conforme a documentação do Swagger.
      const bnmpResponse = await fetch(`${BNMP_API_URL}/bnmpservice/api/pessoas/consultar?cpf=${cpfLimpo}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${BNMP_TOKEN}`,
          'Content-Type': 'application/json'
        }
      })

      if (!bnmpResponse.ok) {
        console.error(`Erro ao consultar BNMP para CPF ${cpfLimpo}:`, await bnmpResponse.text())
        continue
      }

      const bnmpData = await bnmpResponse.json()
      
      // 4. Analisa a resposta do BNMP
      // A estrutura da resposta pode variar. O exemplo abaixo assume um array de mandados.
      // Você precisará adaptar de acordo com o retorno real da API.
      const mandados = bnmpData.mandadosPrisao || [] 
      if (mandados.length > 0) {
        // Verifica se já existe uma notificação para este suspeito nas últimas 24h para evitar spam
        const { data: notifExistente } = await supabase
          .from('notificacao')
          .select('id_notificacao')
          .eq('tipo', 'NOVO_MANDADO_BNMP')
          .eq('dados_extras->>id_suspeito', suspeito.id_suspeito)
          .gte('data_criacao', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
          .maybeSingle()

        if (!notifExistente) {
          // 5. Cria a notificação
          await supabase.from('notificacao').insert({
            tipo: 'NOVO_MANDADO_BNMP',
            titulo: `⚖️ Mandado encontrado no BNMP: ${suspeito.nome_completo}`,
            mensagem: `Foi encontrado um mandado de prisão para ${suspeito.nome_completo} (CPF: ${suspeito.cpf}). Verifique os detalhes no sistema.`,
            dados_extras: {
              id_suspeito: suspeito.id_suspeito,
              cpf: cpfLimpo,
              mandados: mandados // Armazena os dados brutos para auditoria
            },
            lida: false
          })
          resultados.push({ suspeito: suspeito.nome_completo, status: 'Notificação criada' })
        } else {
          resultados.push({ suspeito: suspeito.nome_completo, status: 'Notificação já existe' })
        }
      }
    }

    return new Response(JSON.stringify({ message: 'Consulta concluída', resultados }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Erro geral na execução:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
