function dig_acme_xsfx
        tmux-xpanes -c "watch -n 5 dig +short @{} TXT _acme-challenge.xsteadfastx.org" ns1.your-server.de 8.8.8.8 1.1.1.1 9.9.9.9
end
