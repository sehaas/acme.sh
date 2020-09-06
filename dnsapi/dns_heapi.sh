#!/usr/bin/env sh

########################################################################
# Hurricane Electric API hook script for acme.sh
#
# Environment variables:
#
#  - $HE_DDNS_KEY  (DDNS key for _acme-challenge.subdomain.domain.com)
#
# Author: Sebastian Haas <sehaas@deebas.com>
# Git repo: https://github.com/sehaas/acme.sh

API_ENDPOINT="https://dyn.dns.he.net/nic/update"

#-- dns_heapi_add() - Update TXT record value ----------------------------
# Usage: dns_heapi_add _acme-challenge.subdomain.domain.com "XyZ123..."

dns_heapi_add() {
  _full_domain=$1
  _txt_value=$2
  _info "Update TXT record using DNS-01 Hurricane Electric API hook"

  _update_ddns_record "$_full_domain" "$_txt_value"
  return "$?"
}

#-- dns_heapi_rm() - Clear current TXT record ----------------------------
# Usage: dns_heapi_rm _acme-challenge.subdomain.domain.com "XyZ123..."

dns_heapi_rm() {
  _full_domain=$1
  _info "Clear TXT record using DNS-01 Hurricane Electric API hook"

  _update_ddns_record "$_full_domain" "Acme challenge key"
  return "$?"
}

########################## PRIVATE FUNCTIONS ###########################

_update_ddns_record() {
  _full_domain=$1
  _txt_value=$2

  HE_DDNS_KEY="${HE_DDNS_KEY:-$(_readaccountconf_mutable HE_DDNS_KEY)}"
  if [ -z "$HE_DDNS_KEY" ]; then
    HE_DDNS_KEY=
    _err "No auth details provided. Please set the DDNS Key using the \$HE_DDNS_KEY environment variable."
    return 1
  fi
  _saveaccountconf_mutable HE_DDNS_KEY "$HE_DDNS_KEY"

  password_encoded="$(printf "%s" "${HE_DDNS_KEY}" | _url_encode)"
  body="hostname=${_full_domain}&password=${password_encoded}"
  body="$body&txt=$_txt_value"
  _debug2 body "$body"
  response="$(_post "$body" "$API_ENDPOINT")"
  exit_code="$?"
  _debug2 response "$response"
  if [ "$exit_code" -eq 0 ]; then
    case "$response" in
      good*    )
        _info "TXT record updated successfully."
        ;;
      nochg*   )
        _info "TXT record already contained value."
        ;;
      badauth  )
        _err "Couldn't update the TXT record. Bad DDNS Key."
        return 1
        ;;
      interval )
        _err "Couldn't update the TXT record. Rate limit reached."
        return 1
        ;;
      notxt    )
        _err "Dynamic TXT record not found."
        return 1
        ;;
      *        )
        _err "Unknown response."
        return 1
        ;;
    esac
  else
    _err "Couldn't update the TXT record."
  fi
  return "$exit_code"
}

# vim: et:ts=2:sw=2:
