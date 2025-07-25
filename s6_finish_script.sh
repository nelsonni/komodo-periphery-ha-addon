#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Community Add-on: Komodo Periphery
# Take down the S6 supervision tree when Komodo Periphery fails
# ==============================================================================

bashio::log.info "Komodo Periphery service stopped"

if [[ "$1" -ne 0 ]] && [[ "$1" -ne 256 ]]; then
  bashio::log.warning "Komodo Periphery exited with code $1"
  bashio::log.warning "Attempting restart..."
fi