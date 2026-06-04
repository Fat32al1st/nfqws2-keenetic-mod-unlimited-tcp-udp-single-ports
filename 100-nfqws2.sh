#!/bin/sh

PIDFILE="/opt/var/run/nfqws2.pid"
CONFFILE="/opt/etc/nfqws2/nfqws2.conf"

if [ ! -f "$PIDFILE" ] || ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    exit 0
fi

if [ -f "$CONFFILE" ]; then
    . "$CONFFILE"
fi

ensure_nfqws_chains() {
    local cmd="$1"
    
    if ! $cmd -t mangle -L nfqws_post &>/dev/null; then
        $cmd -t mangle -N nfqws_post 2>/dev/null
    fi
    
    if ! $cmd -t mangle -L nfqws_pre &>/dev/null; then
        $cmd -t mangle -N nfqws_pre 2>/dev/null
    fi
    if [ "$cmd" = "iptables" ]; then
        if ! $cmd -t nat -L nfqws_nat &>/dev/null; then
            $cmd -t nat -N nfqws_nat 2>/dev/null
        fi
    fi
}

ensure_nfqws_chains iptables
if [ -n "$IPV6_ENABLED" ] && [ "$IPV6_ENABLED" -ne "0" ]; then
    ensure_nfqws_chains ip6tables
fi

[ "$table" != "mangle" ] && [ "$table" != "nat" ] && exit
/opt/etc/init.d/S51nfqws2 firewall_"$type"
