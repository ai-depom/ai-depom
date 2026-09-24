# 📜 REGRAS DE OURO — AI-DEPOM

> **Este documento é a constituição do projeto.**
> Toda alteração no AI-DEPOM deve respeitar estas regras.
> Sem exceção. Sem atalho. Sem "só dessa vez".

---

## 🎯 Princípio Fundamental

> **Se funciona, não mexe.**
> **Se precisa mexer, faz com cuidado.**
> **Se quebrar, reverte primeiro. Conserta depois.**

O AI-DEPOM é um sistema **operacional crítico**. Um erro aqui pode:
- Travar uma operação policial em andamento
- Expor dados sensíveis
- Perder informações de mandados
- Comprometer a segurança de agentes

**Por isso, todo cuidado é pouco.**

---

## 📋 As 7 Regras de Ouro

### 🥇 Regra 1 — Cirúrgico
> **Altere apenas o necessário. Nem uma linha a mais.**

- Não "reformar" arquivos que funcionam
- Não "melhorar" código só porque está feio
- Não renomear funções sem necessidade
- Não reformatar código sem motivo

**Exemplo do que NÃO fazer:**
```javascript
// ❌ ERRADO — "aproveitei para melhorar"
function salvarOperacao() {
    // ... código antigo reformatado
    // ... variáveis renomeadas
    // ... logs adicionados
    // ... tratamento de erro novo
}
