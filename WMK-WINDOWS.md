# WMK — Windows nativo (experimental)

Adaptação por Walney Moreira Klein — walneyk@hotmail.com. Projeto original Luis Novo, MIT. Nenhuma alteração no motor original.

## Requisitos
Git, uv, Node.js 22 LTS, SurrealDB CLI 2.x no PATH (não 3.x), espaço para dependências. Python 3.12 via uv. FFmpeg opcional para o primeiro teste de texto; necessário para recursos de áudio/vídeo conforme documentação original. Não usa Docker. Não instala dependências globais automaticamente.

## Primeiro teste
```powershell
git clone -b wmk/windows-native https://github.com/WalneyNF/open-notebook.git WMK-Notebook
cd WMK-Notebook
powershell -NoProfile -ExecutionPolicy Bypass -File .\windows.ps1 -Setup
```
Após instalação, use o mesmo comando sem -Setup. Encerre com Ctrl+C. Logs em wmk-logs. Não compartilhe logs sem revisar dados privados. Preserve .env e surreal_data. O launcher exige portas 8000, 5055 e 3000 livres e usa loopback. Não publique na rede.

## Homologação pendente
- Instalação em Windows 10 real e inicialização dos quatro serviços.
- Configurar Groq (modelo de linguagem) e Ollama (embedding) em Manage / Models; Groq não fornece embeddings. Testar modelos e definir defaults.
- Importar TXT fictício com identificador único; esperar processamento; perguntar pelo identificador e conferir citações.
- Testar perguntas de seguimento, informação ausente, comparação entre fontes, isolamento entre cadernos e persistência após reinício.
- Testar erro do provedor e limite de contexto sem perder histórico.

Não utilizar dados jurídicos reais antes de validar privacidade e fluxo. A execução deste launcher no Windows ainda não foi comprovada. Consulte docs/1-INSTALLATION/from-source.md para o procedimento upstream.
