FROM node:24-bookworm-slim AS base
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN corepack enable
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

FROM base AS build
# tsc needs the dev type packages but none of the install scripts (node-pty would need a compiler).
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY tsconfig.json ./
COPY src ./src
RUN pnpm build

FROM base AS runtime
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl git ripgrep nano vim-tiny \
  && ln -s /usr/bin/vim.tiny /usr/local/bin/vim \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*
# The container has no SSH keys, so GitHub remotes go over HTTPS with gh's token. The bind-mounted
# repo can belong to a different uid than the container user, which git otherwise refuses to read.
RUN git config --system url."https://github.com/".insteadOf "git@github.com:" \
  && git config --system --add url."https://github.com/".insteadOf "ssh://git@github.com/" \
  && git config --system credential."https://github.com".helper "!gh auth git-credential" \
  && git config --system safe.directory '*'
RUN pnpm install --frozen-lockfile --prod && pnpm store prune
COPY bin ./bin
COPY claude ./claude
COPY codex ./codex
COPY docs ./docs
COPY ARCHITECTURE.md ./
COPY --from=build /app/dist ./dist
# HOME is shared by whatever uid compose runs as.
RUN mkdir -m 1777 /home/gr
ENV HOME=/home/gr
COPY docker/entrypoint.sh /usr/local/bin/gr-entrypoint
ENTRYPOINT ["/usr/local/bin/gr-entrypoint"]
