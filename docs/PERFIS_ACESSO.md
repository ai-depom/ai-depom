<!-- ============================================================
     AI-DEPOM - PERFIS DE ACESSO
     ============================================================
     Arquivo: docs/PERFIS_ACESSO.md
     Versão: 1.0.0
     Data: 14/09/2026 - 18:30
     ============================================================
-->
<!-- ============================================================
     AI-DEPOM - README PRINCIPAL
     ============================================================
     Arquivo: README.md
     Versão: 1.1.0
     Data: 14/09/2026 - 18:30
     Autor: AI-DEPOM Team
     ============================================================
     ALTERAÇÕES RECENTES:
     - [14/09/2026 18:30] ✨ Adicionada tabela de perfis de acesso
     - [14/09/2026 18:30] ✨ Adicionada seção de login por matrícula
     - [14/09/2026 18:30] ✨ Adicionada seção de módulos
     - [14/09/2026 18:30] ✨ Documentação completa do sistema
     ============================================================
-->

# 🛡️ AI-DEPOM

**Agência de Inteligência do Departamento de Polícia Metropolitana**  
*Polícia Civil da Bahia*

[![Status](https://img.shields.io/badge/status-em%20desenvolvimento-yellow)]()
[![Versão](https://img.shields.io/badge/versão-3.0.0-blue)]()
[![Licença](https://img.shields.io/badge/licença-GPL%20v2-green)]()
[![LGPD](https://img.shields.io/badge/LGPD-compliant-brightgreen)]()
[![HTTPS](https://img.shields.io/badge/HTTPS-ativo-brightgreen)]()

---

## 📋 Sobre o Projeto

O **AI-DEPOM** é um **sistema integrado de gestão policial** que centraliza o cadastro, consulta, edição e auditoria de informações sobre suspeitos, com foco em **segurança, rastreabilidade e conformidade legal (LGPD)**.

### 🎯 Objetivo

Modernizar o processo de gestão de informações policiais, substituindo planilhas e sistemas legados por uma **plataforma web segura, auditável e escalável**.

### 🌟 Diferenciais

- 🔐 **Auditoria completa** — toda alteração registrada com autor, data, motivo e valores antes/depois
- 🚫 **Soft delete** — nada é apagado fisicamente do banco
- 👥 **7 perfis de acesso** com permissões granulares por campo
- 📸 **Bucket privado** para fotos, com URLs assinadas e expiração automática
- ✅ **LGPD/GDPR compliant** — rastreabilidade total, direito ao esquecimento, minimização de dados
- 🌐 **Deploy em Cloudflare Workers** — HTTPS automático, rede global, alta disponibilidade

---

## 🚀 Tecnologias Utilizadas

### Frontend
- **HTML5 + CSS3 + JavaScript (Vanilla)** — sem frameworks, leve e rápido
- **Bootstrap 5.3** — grid responsivo e componentes
- **Font Awesome 6.4** — ícones vetoriais
- **Design System AI-DEPOM** — tema dark com verde neon (#00ff88)

### Backend & Infraestrutura
- **[Supabase](https://supabase.com)** — PostgreSQL gerenciado + Auth + Storage + APIs REST
- **[Cloudflare Workers](https://workers.cloudflare.com)** — hospedagem do frontend na edge
- **[GitHub](https://github.com/ai-depom)** — versionamento e CI/CD

### Banco de Dados (PostgreSQL via Supabase)
- **Row Level Security (RLS)** — controle de acesso por linha
- **Triggers de auditoria** — histórico versionado automático
- **CHECK constraints** — validação de integridade no banco
- **Soft delete** — coluna `deletado` em todas as tabelas

---

## 📁 Estrutura do Projeto

---

## 🔐 Login no Sistema

### 🎯 Como acessar

O sistema aceita **dois formatos de login**:

| Formato | Exemplo | Quando usar |
|---------|---------|-------------|
| **Matrícula** | `ADM-MASTER-001` | Uso diário (mais rápido) |
| **E-mail** | `ana.reboucas@pcivil.ba.gov.br` | Recuperação de senha |

**O sistema detecta automaticamente** qual dos dois você digitou:
- Se tem `@` → trata como **e-mail**
- Se NÃO tem `@` → trata como **matrícula**

### 🔑 Credenciais do MASTER

| Campo | Valor |
|-------|-------|
| **Matrícula** | `ADM-MASTER-001` |
| **E-mail** | `ana.reboucas@pcivil.ba.gov.br` |
| **Perfil** | ADMINISTRADOR_MASTER (nível 10) |

### 🆘 Esqueci minha senha

1. Clica em **"Esqueci minha senha"** na tela de login
2. Digita o **e-mail** cadastrado
3. Recebe o link por e-mail (válido por 2 horas)
4. Clica no link → redefine a senha
5. Faz login com a nova senha

---

## 👥 Perfis de Acesso

O sistema possui **7 perfis hierárquicos**, cada um com permissões específicas.

| ID | Perfil | Nível | Gerenciar Usuários? | Descrição |
|:--:|--------|:-----:|:-------------------:|-----------|
| 1 | **ADMINISTRADOR_MASTER** | 10 | ✅ Sim | Acesso total + gerenciamento de usuários |
| 2 | **ADMINISTRADOR** | 9 | ❌ Não | Acesso total, exceto gerenciar usuários |
| 3 | **DELEGADO** | 8 | ❌ Não | Todos os dados + informações criminais |
| 4 | **INVESTIGADOR** | 7 | ❌ Não | Dados de investigação |
| 5 | **PERITO** | 6 | ❌ Não | Dados técnicos e evidências |
| 6 | **ANALISTA** | 5 | ❌ Não | Apenas consultas e relatórios |
| 7 | **CONSULTA_EXTERNA** | 3 | ❌ Não | Acesso limitado para consultas externas |

### 📊 Matriz de Permissões

| Ação | MASTER | ADMIN | DELEGADO | INVESTIGADOR | PERITO | ANALISTA | CONSULTA_EXT |
|------|:------:|:-----:|:--------:|:------------:|:------:|:--------:|:------------:|
| Cadastrar suspeito | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Editar dados básicos | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Editar CPF/RG/nome mãe | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Editar características físicas | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Editar status/penalidade | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Adicionar fotos | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Ver histórico completo | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Gerar relatórios | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Emitir alertas | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Gerenciar usuários** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Alterar configurações** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### 🎯 Como escolher o perfil ao cadastrar

| Situação | Perfil recomendado |
|----------|-------------------|
| Responsável de TI | **MASTER** |
| Chefe de setor | **ADMINISTRADOR** |
| Delegado | **DELEGADO** |
| Investigador | **INVESTIGADOR** |
| Perito criminal | **PERITO** |
| Analista de dados | **ANALISTA** |
| Órgão parceiro | **CONSULTA_EXTERNA** |

---

## 🔐 Segurança

### Autenticação
- ✅ **Supabase Auth** — e-mail + senha, com JWT
- ✅ **Redefinição de senha** via e-mail com token temporário
- ✅ **Bloqueio de sessão** após **5 minutos** de inatividade
- ✅ **Primeiro acesso** força troca de senha

### Autorização
- ✅ **7 perfis de acesso** hierárquicos
- ✅ **Permissões por campo** — cada perfil edita apenas campos específicos

### Proteção de Dados
- ✅ **RLS habilitado** em todas as tabelas
- ✅ **Bucket privado** para fotos (`fotos-suspeitos`)
- ✅ **Signed URLs** com expiração de 1h
- ✅ **Hash SHA-256** dos arquivos
- ✅ **Triggers de auditoria** — impossível alterar sem registro

---

## 📊 Banco de Dados

### Tabelas principais

| Tabela | Descrição |
|--------|-----------|
| `usuarios` | Usuários do sistema (espelho do `auth.users`) |
| `perfil_acesso` | Perfis e permissões |
| `suspeito` | Cadastro de suspeitos |
| `arquivo_midia` | Fotos e mídias vinculadas a suspeitos |
| `suspeito_historico` | Histórico versionado de alterações |
| `suspeito_campos_editaveis` | Controle de permissão por campo |

### Políticas de integridade

- 🚫 **Soft delete obrigatório** — trigger `prevent_physical_delete` bloqueia `DELETE`
- ✅ **Histórico automático** — trigger `auditar_alteracao_suspeito` grava toda alteração
- 🔒 **CHECK constraints** — valores válidos para `nivel_seguranca`, `status`, `tipo_midia`

---

## 🗺️ Módulos do Sistema

| # | Módulo | Arquivo | Status |
|---|--------|---------|:------:|
| 1 | Apresentação | `01-apresentacao.html` | ✅ |
| 2 | Login | `02-login.html` | ✅ |
| 3 | Primeiro Acesso | `03-primeiro-acesso.html` | ✅ |
| 4 | Redefinir Senha | `03b-redefinir-senha.html` | ✅ |
| 5 | Dashboard | `04-dashboard.html` | ✅ |
| 6 | Cadastro de Usuário | `05-cadastro-usuario.html` | ✅ |
| 7 | Cadastro de Suspeito | `06-cadastro-suspeito.html` | ✅ |
| 8 | Consulta | `07-consulta.html` | ✅ |
| 9 | Relatórios | `08-relatorios.html` | ✅ |
| 10 | Configurações | `09-configuracoes.html` | ✅ |
| 11 | Mapa de Operações | `10-mapa-operacoes.html` | ⏳ |
| 12 | Mandados | `11-mandados.html` | ⏳ |
| 13 | Auditoria | `12-auditoria.html` | ⏳ |

---

## 🚀 Como Executar

### Pré-requisitos
- Navegador moderno (Chrome, Edge, Firefox, Safari)
- Acesso à internet
- **Não requer instalação local** — sistema 100% web

### Acesso

**Produção (Cloudflare):**
# 👥 Perfis de Acesso — AI-DEPOM

O AI-DEPOM possui **7 perfis hierárquicos**, cada um com permissões específicas.

---

## 📊 Tabela Resumo

| ID | Perfil | Nível | Gerenciar Usuários? |
|:--:|--------|:-----:|:-------------------:|
| 1 | ADMINISTRADOR_MASTER | 10 | ✅ Sim |
| 2 | ADMINISTRADOR | 9 | ❌ Não |
| 3 | DELEGADO | 8 | ❌ Não |
| 4 | INVESTIGADOR | 7 | ❌ Não |
| 5 | PERITO | 6 | ❌ Não |
| 6 | ANALISTA | 5 | ❌ Não |
| 7 | CONSULTA_EXTERNA | 3 | ❌ Não |

---

## 👑 1. ADMINISTRADOR_MASTER (Nível 10)

**Descrição:** *Administrador Master - Único com poder de gerenciar usuários*

### ✅ Pode fazer
- Tudo no sistema
- Criar/editar/desativar usuários
- Definir perfis de acesso
- Resetar senhas de outros usuários
- Auditar qualquer ação
- Ver todos os dados
- Alterar configurações globais
- Emitir alertas

### ❌ Não pode fazer
- Nada é restrito ao MASTER

### 👤 Quem deve ter
Apenas **1 pessoa** — o responsável máximo pela TI do DEPOM.

---

## 🔧 2. ADMINISTRADOR (Nível 9)

**Descrição:** *Administrador - Acesso total, exceto gerenciamento de usuários*

### ✅ Pode fazer
- Cadastrar/editar suspeitos
- Consultar todos os dados
- Editar qualquer campo
- Ver histórico
- Ver fotos
- Emitir alertas
- Gerar relatórios

### ❌ Não pode fazer
- Criar/editar usuários
- Definir perfis
- Resetar senhas de outros
- Alterar configurações críticas

### 👤 Quem deve ter
Chefe de setor, coordenador de TI, gestor operacional.

---

## ⚖️ 3. DELEGADO (Nível 8)

**Descrição:** *Acesso a todos os dados, exceto administração*

### ✅ Pode fazer
- Cadastrar/editar suspeitos
- Editar dados básicos + criminais + endereço
- Ver histórico
- Ver fotos
- Emitir alertas
- Gerar relatórios

### ❌ Não pode fazer
- Editar CPF, RG, nome da mãe, data de nascimento
- Gerenciar usuários
- Alterar configurações críticas

### 👤 Quem deve ter
Delegados de polícia, autoridades policiais.

---

## 🔍 4. INVESTIGADOR (Nível 7)

**Descrição:** *Acesso a dados de investigação*

### ✅ Pode fazer
- Cadastrar/editar suspeitos
- Editar dados básicos + endereço + características físicas
- Adicionar fotos
- Consultar todos os dados
- Ver histórico

### ❌ Não pode fazer
- Editar CPF, RG, nome da mãe, data de nascimento
- Editar status_atual
- Editar nível de periculosidade
- Gerenciar usuários

### 👤 Quem deve ter
Investigadores, agentes de polícia.

---

## 🔬 5. PERITO (Nível 6)

**Descrição:** *Acesso a dados técnicos e evidências*

### ✅ Pode fazer
- Adicionar/editar características físicas
- Consultar dados
- Ver fotos
- Adicionar fotos técnicas

### ❌ Não pode fazer
- Editar dados básicos (nome, CPF)
- Editar informações criminais (status)
- Gerenciar usuários

### 👤 Quem deve ter
Peritos criminais, médicos legistas.

---

## 📊 6. ANALISTA (Nível 5)

**Descrição:** *Acesso apenas para consultas e relatórios*

### ✅ Pode fazer
- Consultar suspeitos
- Ver fotos
- Ver histórico
- Gerar relatórios
- Ver dashboard

### ❌ Não pode fazer
- Cadastrar suspeitos
- Editar qualquer campo
- Adicionar fotos
- Gerenciar usuários

### 👤 Quem deve ter
Analistas de inteligência, estatísticos.

---

## 🌐 7. CONSULTA_EXTERNA (Nível 3)

**Descrição:** *Acesso limitado para consultas externas*

### ✅ Pode fazer
- Consultar suspeitos (dados básicos)
- Ver fotos

### ❌ Não pode fazer
- Ver histórico completo
- Ver dados sensíveis (CPF, RG, endereço)
- Gerar relatórios completos
- Cadastrar/editar qualquer coisa

### 👤 Quem deve ter
Órgãos externos, polícias de outros estados, parceiros institucionais.

---

## 📌 Observação sobre permissões por campo

As permissões por campo estão configuradas na tabela `suspeito_campos_editaveis`:

```sql

### Primeiro acesso

1. Acesse a **tela de login**
2. Use as credenciais fornecidas pelo administrador:
   - **Matrícula:** `ADM-MASTER-001`
   - **Senha:** fornecida pelo MASTER
3. No primeiro acesso, você será redirecionado para criar uma **nova senha**
4. Após isso, será levado ao **dashboard**

---

## 🧪 Testes

### Fluxo de teste manual

1. **Login** com usuário válido (matrícula ou e-mail)
2. **Cadastrar** um suspeito com foto
3. **Consultar** o suspeito na busca
4. **Editar** um campo (com justificativa obrigatória)
5. **Ver o histórico** da alteração
6. **Ver a galeria** de fotos
7. **Logout** e login novamente

### Fluxo de recuperação de senha

1. Clicar em **"Esqueci minha senha"** no login
2. Digitar o e-mail
3. Receber o link por e-mail
4. Criar uma nova senha
5. Fazer login

---

## 📈 Roadmap

### ✅ Concluído
- [x] Autenticação com Supabase Auth
- [x] Login por matrícula ou e-mail (detecção automática)
- [x] Cadastro de suspeitos com upload de fotos
- [x] Consulta com filtros e busca
- [x] Edição com auditoria versionada
- [x] Histórico de alterações
- [x] Galeria de fotos
- [x] Perfis de acesso granulares
- [x] Redefinição de senha via e-mail
- [x] Relatórios e estatísticas
- [x] Deploy em Cloudflare Workers

### 🚧 Em desenvolvimento
- [ ] Mapa de operações (`10-mapa-operacoes.html`)
- [ ] Módulo de mandados (`11-mandados.html`)
- [ ] Módulo de auditoria (`12-auditoria.html`)
- [ ] Dashboard com estatísticas em tempo real

### 🔮 Futuro
- [ ] Domínio próprio (`ai-depom.com.br`)
- [ ] SMTP institucional (Resend)
- [ ] App mobile (PWA)
- [ ] Integração com sistemas externos (SSP/BA)
- [ ] BI e análise preditiva
- [ ] Backup automático diário

---

## 👥 Equipe

**Coordenação:**
- Ana Clara — *Coordenação de Inteligência*

**Desenvolvimento:**
- Eng. Computação Itamar Souza — *Arquitetura e Desenvolvimento*
- Equipe de Inteligência do DEPOM

---

## 📄 Licença

Este projeto está licenciado sob a **GNU General Public License v2.0** — veja o arquivo [LICENSE](LICENSE) para detalhes.

---

## 📞 Contato

**AI-DEPOM — Agência de Inteligência**  
Departamento de Polícia Metropolitana  
Polícia Civil da Bahia

🌐 **Produção:** [ai-depom.ai-depom.workers.dev](https://ai-depom.ai-depom.workers.dev)  
💻 **Repositório:** [github.com/ai-depom/ai-depom](https://github.com/ai-depom/ai-depom)

---

## 🏆 Agradecimentos

À **Diretoria do DEPOM** pelo apoio institucional.  
À **equipe de inteligência** pela visão operacional.  
À **Polícia Civil da Bahia** pela confiança.

---

<p align="center">
  <strong>AI-DEPOM</strong> · <em>"Inteligência a serviço da segurança pública"</em>
</p>

<p align="center">
  © 2026 · Sistema em desenvolvimento · Todos os direitos reservados
</p>

SELECT nome_campo, perfis_permitidos 
FROM public.suspeito_campos_editaveis 
ORDER BY ordem;
