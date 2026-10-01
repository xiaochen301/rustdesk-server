# XC custom all-in-one image for the rustdesk deployments (HK + IOC).
#
# Base: lejianwen/rustdesk-server-s6 (same image family both deployments run).
# Overlays our forked builds:
#   hbbs    - rustdesk-server fork (xc/ws-enhance: ws enhancements + 1.1.17 line)
#   hbbr    - same fork
#   apimain - rustdesk-api fork (xc/auto-sync: v2.7 + AutoSyncService)
#
# Built and pushed by .github/workflows/xc-build.yml to:
#   ghcr.io/xiaochen301/rustdesk-server-xc:latest
FROM lejianwen/rustdesk-server-s6:latest

COPY xc-artifacts/hbbs    /usr/bin/hbbs
COPY xc-artifacts/hbbr    /usr/bin/hbbr
COPY xc-artifacts/apimain /app/apimain

RUN chmod +x /usr/bin/hbbs /usr/bin/hbbr /app/apimain
