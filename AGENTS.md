# NanoClaw

See `CLAUDE.md` for codebase overview, key files, and development commands.

## Cursor Cloud specific instructions

### Services

NanoClaw is a single Node.js process (orchestrator) that connects to messaging platforms (WhatsApp/Telegram) and spawns Claude Agent SDK processes. There is also a sub-package at `container/agent-runner/` used inside containers.

### Running the application

- `npm run dev` starts the orchestrator with hot reload via `tsx`.
- The app requires at least one messaging channel. Set `TELEGRAM_ONLY=true` to skip WhatsApp QR auth (useful for headless/cloud environments). Without `TELEGRAM_BOT_TOKEN`, the Telegram channel is also skipped, but the orchestrator still starts and exposes the HTTP health server.
- Health check: `curl http://localhost:3000/health`

### Lint / Typecheck / Test / Build

Standard commands from `package.json`:

| Task | Command |
|------|---------|
| Typecheck | `npm run typecheck` |
| Format check | `npm run format:check` |
| Build (main) | `npm run build` |
| Build (agent-runner) | `cd container/agent-runner && npm run build` |
| Tests | `npm test` |

### Known test caveat

3 tests in `skills-engine/__tests__/fetch-upstream.test.ts` fail due to `git archive --remote` not being supported in the test environment's git transport. These are pre-existing and unrelated to local setup.

### Environment variables

- `ANTHROPIC_API_KEY` — required for agents to function (not needed for orchestrator startup or tests).
- `TELEGRAM_BOT_TOKEN` — Telegram channel token (optional).
- `TELEGRAM_ONLY=true` — skip WhatsApp connection (useful in cloud/headless envs).
- Secrets can also be placed in a `.env` file at the project root.
