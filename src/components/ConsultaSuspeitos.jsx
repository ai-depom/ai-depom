// ============================================================
// COMPONENTE DE CONSULTA — REACT
// Caminho: src/components/ConsultaSuspeitos.jsx
// ============================================================

import { useEffect, useState } from 'react';
import { buscarSuspeitosComFoto } from '../lib/consulta-suspeitos.js';

export default function ConsultaSuspeitos() {
    const [lista, setLista] = useState([]);
    const [carregando, setCarregando] = useState(true);
    const [erro, setErro] = useState(null);

    useEffect(() => {
        buscarSuspeitosComFoto()
            .then(setLista)
            .catch(setErro)
            .finally(() => setCarregando(false));
    }, []);

    if (carregando) return <p>Carregando suspeitos...</p>;
    if (erro) return <p style={{ color: 'red' }}>Erro: {erro.message}</p>;
    if (lista.length === 0) return <p>Nenhum suspeito encontrado.</p>;

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {lista.map(s => (
                <div
                    key={s.id_suspeito}
                    style={{
                        display: 'flex',
                        gap: 12,
                        padding: 12,
                        border: '1px solid #ddd',
                        borderRadius: 8,
                    }}
                >
                    {s.fotoUrl ? (
                        <img
                            src={s.fotoUrl}
                            alt={s.nome_completo}
                            style={{
                                width: 80,
                                height: 80,
                                objectFit: 'cover',
                                borderRadius: 8,
                            }}
                        />
                    ) : (
                        <div
                            style={{
                                width: 80,
                                height: 80,
                                background: '#eee',
                                borderRadius: 8,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                fontSize: 12,
                                color: '#666',
                            }}
                        >
                            Sem foto
                        </div>
                    )}

                    <div>
                        <strong>{s.nome_completo}</strong>
                        <br />
                        <small>Apelido: {s.apelido || '-'}</small>
                        <br />
                        <span
                            style={{
                                display: 'inline-block',
                                padding: '2px 8px',
                                background: '#007bff',
                                color: '#fff',
                                borderRadius: 4,
                                fontSize: 12,
                                marginRight: 6,
                            }}
                        >
                            {s.status_atual}
                        </span>
                        <span
                            style={{
                                display: 'inline-block',
                                padding: '2px 8px',
                                background: '#6c757d',
                                color: '#fff',
                                borderRadius: 4,
                                fontSize: 12,
                            }}
                        >
                            {s.nivel_periculosidade || '-'}
                        </span>
                    </div>
                </div>
            ))}
        </div>
    );
}
