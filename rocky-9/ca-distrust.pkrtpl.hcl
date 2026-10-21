mkdir -p /etc/pki/ca-trust/source/blocklist
cat > /etc/pki/ca-trust/source/blocklist/emudhra-distrust.pem << 'EOF'
${pem}
EOF
update-ca-trust extract
