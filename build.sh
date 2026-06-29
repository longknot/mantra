#!/usr/bin/env bash
mkdir -p bin build
rm -rf build/*

fpc mantra.lpr -FEbin -FUbuild -Fusrc -Fu"vendor/*" -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0

if [[ "${1:-}" == "--all" ]]; then
  fpc mantra_server.lpr -FEbin -FUbuild -Fusrc -Fu"vendor/*" -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
  fpc mantra_mcp_server.lpr -FEbin -FUbuild -Fusrc -Fu"vendor/*" -Fuvendor/mcp/Src/Base -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
fi
