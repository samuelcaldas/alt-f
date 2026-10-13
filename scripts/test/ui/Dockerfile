FROM python:3.12-alpine AS checks
ENV TZ=America/Sao_Paulo PYTHONDONTWRITEBYTECODE=1
WORKDIR /tests
COPY customroot/usr/www /usr/www
COPY rootfsfiles-base.lst /source/rootfsfiles-base.lst
COPY scripts/test/ui /tests
COPY scripts/test/ui/fixtures/misc.conf /etc/misc.conf
RUN chmod -R a-x /usr/www/cgi-bin && chmod a+x /usr/www/cgi-bin
CMD ["python", "-m", "unittest", "discover", "-v"]

FROM mcr.microsoft.com/playwright:v1.58.2-noble AS browser
ENV TZ=America/Sao_Paulo PYTHONDONTWRITEBYTECODE=1
WORKDIR /tests
RUN apt-get update && apt-get install -y --no-install-recommends busybox-static python3 \
    && rm -rf /var/lib/apt/lists/*
COPY scripts/test/ui/package.json /tests/package.json
RUN npm install --omit=optional --ignore-scripts
COPY customroot/usr/www /usr/www
COPY rootfsfiles-base.lst /source/rootfsfiles-base.lst
COPY scripts/test/ui /tests
COPY scripts/test/ui/fixtures/misc.conf /etc/misc.conf
RUN chmod -R a-x /usr/www/cgi-bin && chmod a+x /usr/www/cgi-bin
HEALTHCHECK NONE
CMD ["node", "browser_checks.js"]
