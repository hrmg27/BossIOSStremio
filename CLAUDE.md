# CLAUDE.md — App iOS pessoal para Stremio (com sync de estado)

> Ficheiro de contexto permanente para o Claude Code. Lê isto ao arrancar em cada
> sessão. Contém o objetivo do projeto, a stack, as decisões já tomadas, a mecânica
> da API do Stremio e as regras da casa. Para a tarefa concreta de cada sessão o
> autor dará um prompt à parte — este ficheiro é o pano de fundo.

---

## 1. Objetivo

App **iOS pessoal** (uso próprio, **não vai ser publicada na App Store**) para aceder
à conta Stremio do autor e ver conteúdo diretamente no iPhone, mantendo o **estado de
reprodução sincronizado** entre iPhone, PC e TV da sala — tal como o cliente Stremio
oficial faz nas outras plataformas.

O problema que resolve: o método atual (Stremio Web no iOS a passar o stream para o
VLC) faz um *handoff burro* — o player externo nunca reporta o progresso de volta à
conta, por isso ao reabrir um vídeo ele começa sempre do início, e as legendas
resolvidas pelo add-on perdem-se no caminho. Uma app com **player embutido** fecha
esse ciclo: toca, mede a posição, escreve na conta, e lê na próxima vez.

Comportamento-alvo: parar um episódio a meio no iPhone e continuar de onde ficou no
PC ou na TV (e vice-versa), com as legendas certas já carregadas.

---

## 2. Stack e decisões técnicas (fechadas)

- **Linguagem/UI:** Swift + **SwiftUI**.
- **Player:** **`AVPlayer` nativo, embutido na app** (nada de player externo / handoff).
  Aproveitar PiP, AirPlay, controlos no lock screen e reprodução em background.
- **Rede:** `URLSession` / `async-await`. Sem dependências pesadas desnecessárias.
- **Streams suportados:**
  - HTTP progressivo e **HLS** → tocam diretamente no `AVPlayer`.
  - **Torrents → resolver via serviço debrid** (Real-Debrid / AllDebrid), que devolve
    um link HTTP direto. **NÃO** tentar correr o "Stremio Service" / streaming server
    de torrents — não existe/não corre em iOS. Torrents sem debrid ficam fora de âmbito.
- **Legendas:** obter dos add-ons de legendas e carregar as faixas (`.srt` / `.vtt`)
  no próprio `AVPlayer`. Guardar preferência de idioma.
- **Persistência local:** guardar `authKey`, preferências e uma cache leve da library.
  `authKey` vai no **Keychain** (nunca em UserDefaults nem em texto simples).
- **Distribuição:** **sideload via SideStore** com Apple ID grátis (auto-refresh do
  certificado de 7 dias no próprio dispositivo). Sem conta de developer paga por agora.

---

## 3. Arquitetura sugerida

Separar em camadas claras:

- `StremioAPI` — cliente da API da conta (login, add-ons, library/datastore).
- `AddonClient` — fala com os add-ons individuais (manifest, catalog, meta, stream,
  subtitles) seguindo o Addon Protocol.
- `DebridResolver` — recebe o resultado de um stream de torrent e devolve o link HTTP
  direto (Real-Debrid/AllDebrid).
- `PlayerViewModel` + `PlayerView` — o `AVPlayer` embutido, gestão de faixas de
  legendas e o loop de sync de progresso.
- `LibrarySync` — lê/escreve o estado de reprodução na conta (a peça central).
- `KeychainStore` — armazenamento seguro do `authKey`.

A **peça central e prioritária** é o `LibrarySync` + login: é o que faz o resume
funcionar em todo o lado. Construir e validar isso primeiro, antes de polir UI.

---

## 4. API da conta Stremio — mecânica

> Base: `https://api.strem.io/api/`. Todos os pedidos são `POST` com corpo JSON e
> devolvem JSON. **Os nomes exatos de campos abaixo são do meu melhor conhecimento —
> confirmar sempre contra o `stremio-core` (ver secção 7) antes de assumir shapes,
> especialmente na estrutura do `libraryItem`.**

### Login
`POST /login` com `{ "email": ..., "password": ..., "type": "Login" }`
→ resposta contém `result.authKey` (guardar no Keychain) e `result.user`.

### Add-ons instalados na conta
`POST /addonCollectionGet` com `{ "authKey": ..., "update": true }`
→ devolve a coleção de add-ons (cada um com o seu `transportUrl`/manifest). É daqui
que sabes que fontes de stream e de legendas o utilizador tem instaladas.

### Library / progresso de reprodução (o núcleo do sync)
- Ler: `POST /datastoreGet` com `{ "authKey": ..., "collection": "libraryItem", "all": true }`
- Escrever: `POST /datastorePut` com `{ "authKey": ..., "collection": "libraryItem", "changes": [ <libraryItem>, ... ] }`

Cada `libraryItem` representa um filme/série na biblioteca e traz um objeto de estado
(tipicamente algo como `state`) com, entre outros:
- posição de reprodução (offset em **milissegundos**),
- duração total,
- flags de "visto"/"terminado",
- timestamp do último visionamento.

**Fluxo de sync a implementar:**
1. Ao abrir um título, ler o `libraryItem` correspondente e fazer `seek` para a
   posição guardada (resume).
2. Durante a reprodução, ir lendo o `currentTime` do `AVPlayer`.
3. Ao pausar / ir para background / sair / terminar, escrever o `libraryItem`
   atualizado via `datastorePut`. Assim o PC e a TV passam a ver o mesmo resume.
4. Respeitar/atualizar o timestamp de "última modificação" para o merge cross-device
   ficar coerente (last-write-wins pela `_mtime`, confirmar no core).

---

## 5. Add-on Protocol — resolução de streams e legendas

Cada add-on tem um manifest em `{transportUrl}/manifest.json` e expõe recursos por
URL previsível:

- **Stream:** `{addonBaseUrl}/stream/{type}/{id}.json` → `{ "streams": [ { "url": ..., "title": ... }, ... ] }`
- **Subtitles:** `{addonBaseUrl}/subtitles/{type}/{id}.json` → `{ "subtitles": [ { "url": ..., "lang": ... }, ... ] }`
- **Meta:** `{addonBaseUrl}/meta/{type}/{id}.json`
- **Catalog:** `{addonBaseUrl}/catalog/{type}/{id}.json`

`type` é `movie` / `series` / etc. O `id` para episódios de série costuma ter o
formato `ttXXXXXXX:season:episode` (ex.: `tt1234567:1:5`); para filmes é o imdb id.

Fluxo: escolher título → chamar `stream` nos add-ons instalados → se o stream for
torrent, passar pelo `DebridResolver` → obter link HTTP → carregar no `AVPlayer` →
em paralelo chamar `subtitles` e adicionar as faixas ao player.

---

## 6. Distribuição / execução (sideload gratuito)

- Compilar no Xcode com **Apple ID grátis** e instalar no iPhone do autor.
- Certificado grátis expira a cada **7 dias**; usar **SideStore** para auto-refresh
  no próprio dispositivo (sem precisar de computador ligado).
- Limite de 3 apps do Apple ID grátis é irrelevante (só existe esta app).
- Conta de developer paga (99 USD/ano, validade 1 ano) fica como plano B, **não usar
  já**.
- Bundle ID estável e próprio (ex.: `com.<autor>.stremioios`) para o refresh do
  SideStore ser consistente.

---

## 7. Referências

- **`stremio-core`** (Rust, open source) — implementação oficial do cliente. É a
  fonte de verdade para auth, estrutura do `libraryItem`, lógica de sync e resolução
  de add-ons. **Consultar sempre que houver dúvida sobre shapes da API em vez de
  adivinhar.**
- Documentação do **Stremio Addon SDK** para o Addon Protocol (manifest, stream,
  subtitles, meta, catalog).
- APIs de **Real-Debrid** / **AllDebrid** para o `DebridResolver`.

---

## 8. Regras da casa (o Claude Code deve respeitar)

- **Nada de segredos hardcoded.** `authKey`, credenciais e tokens de debrid vão para o
  Keychain / configuração, nunca commitados nem em texto simples no código.
- **Não reimplementar o streaming server de torrents.** Torrents resolvem-se sempre
  via debrid.
- **Não introduzir dependências grandes** sem justificação; preferir frameworks
  nativos da Apple (`AVFoundation`, `URLSession`, `SwiftUI`).
- **Confirmar shapes da API contra o `stremio-core`** antes de assumir nomes de campos.
- Código em **Swift idiomático**, `async/await`, tipado; tratar erros de rede de forma
  explícita (a app é para uso real, não protótipo descartável).
- Comentários e nomes de símbolos em **inglês**; texto virado ao utilizador pode ser
  em português.
- Manter as camadas da secção 3 separadas — não misturar chamadas de rede dentro das
  Views.
- Antes de mexer em funcionalidade nova, garantir que **login + resume de progresso**
  continuam a funcionar (é o coração do projeto).

---

## 9. Ordem de trabalho sugerida

1. Projeto SwiftUI base a compilar e a correr no dispositivo via SideStore ("hello world").
2. `StremioAPI.login` + guardar `authKey` no Keychain.
3. `LibrarySync`: ler a library e mostrar uma lista simples do "continuar a ver".
4. `PlayerView` com `AVPlayer` a tocar um stream HTTP direto + resume (seek para a
   posição guardada) + escrita do progresso ao pausar/sair.
5. `AddonClient` para resolver streams a partir dos add-ons instalados.
6. `DebridResolver` para links de torrent.
7. Legendas dos add-ons carregadas no player + preferência de idioma.
8. Polimento de UI, PiP, AirPlay, background.

---

## 10. Notas legais

O acesso à conta própria e a sincronização de estado são legítimos. A zona cinzenta é
sempre o **conteúdo que os add-ons servem** — isso é da responsabilidade do que o
utilizador instala, e está fora do âmbito deste código. A app não aloja nem distribui
conteúdo; é apenas um cliente da conta do próprio utilizador.
