#!/usr/bin/env bash
set -euo pipefail

# 0. Parameter laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

echo "=========================================================="
echo "   Hardening: UFW, Fail2ban, Auditd & OS Security"
echo "=========================================================="

# ========================================================
# 1. Hardening auf app-vm
# ========================================================
echo -e "\n[1/2] Führe OS- & Firewall-Härtung auf app-vm aus..."
az vm run-command invoke \
  --resource-group "$RG" \
  --name "app-vm" \
  --command-id RunShellScript \
  --scripts "
    set -e
    echo '=== 1. Sicherheits-Pakete installieren ==='
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a
    apt-get update
    apt-get install -y ufw fail2ban auditd audispd-plugins unattended-upgrades

    echo '=== 2. UFW Firewall konfigurieren ==='
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    # SSH nur aus dem internen VNet / Bastion erlauben (10.0.0.0/16)
    ufw allow from 10.0.0.0/16 to any port 22 proto tcp comment 'SSH nur intern/Bastion'

    # Web-Traffic erlauben (Port 80 HTTP und Port 443 HTTPS)
    ufw allow 80/tcp comment 'HTTP Webserver'
    ufw allow 443/tcp comment 'HTTPS Webserver'
    ufw --force enable
    ufw status verbose

    echo '=== 3. Fail2ban konfigurieren ==='
    cat <<'EOF_F2B' > /etc/fail2ban/jail.local
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
backend  = systemd

[sshd]
enabled = true
port    = 22
mode    = aggressive

[nginx-http-auth]
enabled = true
port    = http,https

[nginx-botsearch]
enabled = true
port    = http,https
EOF_F2B

    systemctl enable fail2ban
    systemctl restart fail2ban
    fail2ban-client status

    echo '=== 4. Auditd Audit-Logging einrichten ==='
    cat <<'EOF_AUDIT' > /etc/audit/rules.d/hardening.rules
# Überwache Änderungen an sicherheitsrelevanten Benutzer- und Gruppen-Dateien
-w /etc/passwd -p wa -k identity_changes
-w /etc/shadow -p wa -k identity_changes
-w /etc/group -p wa -k identity_changes
-w /etc/sudoers -p wa -k sudo_changes
-w /etc/sudoers.d/ -p wa -k sudo_changes

# Überwache SSH-Konfiguration
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes

# Überwache Systemaufrufe für Rechteänderungen
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S lchown -S fchownat -F auid>=1000 -F auid!=4294967295 -k perm_mod
EOF_AUDIT

    augenrules --load || service auditd restart
    systemctl enable auditd

    echo '=== 5. SSH- und Kernel-Hardening (Sysctl) ==='
    # SSH Härtung
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config || true
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config || true
    systemctl restart ssh || systemctl restart sshd

    # Kernel-Netzwerkschutz
    cat <<'EOF_SYSCTL' > /etc/sysctl.d/99-hardening.conf
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
EOF_SYSCTL
    sysctl -p /etc/sysctl.d/99-hardening.conf

    # Automatische Sicherheitsupdates aktivieren
    systemctl enable unattended-upgrades
    echo '=== Hardening auf app-vm abgeschlossen ==='
  " \
  --output table

# ========================================================
# 2. Hardening auf db-vm
# ========================================================
echo -e "\n[2/2] Führe OS- & Firewall-Härtung auf db-vm aus..."
az vm run-command invoke \
  --resource-group "$RG" \
  --name "db-vm" \
  --command-id RunShellScript \
  --scripts "
    set -e
    echo '=== 1. Sicherheits-Pakete installieren ==='
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a
    apt-get update
    apt-get install -y ufw fail2ban auditd audispd-plugins unattended-upgrades

    echo '=== 2. UFW Firewall konfigurieren ==='
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    # SSH nur aus internem VNet/Bastion erlauben
    ufw allow from 10.0.0.0/16 to any port 22 proto tcp comment 'SSH intern/Bastion'

    # PostgreSQL (5432) STRIKT NUR aus dem App-Subnetz (10.0.1.0/24) erlauben
    ufw allow from 10.0.1.0/24 to any port 5432 proto tcp comment 'PostgreSQL nur aus App-Subnetz'
    ufw --force enable
    ufw status verbose

    echo '=== 3. Fail2ban konfigurieren ==='
    cat <<'EOF_F2B' > /etc/fail2ban/jail.local
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
backend  = systemd

[sshd]
enabled = true
port    = 22
mode    = aggressive
EOF_F2B

    systemctl enable fail2ban
    systemctl restart fail2ban
    fail2ban-client status

    echo '=== 4. Auditd Audit-Logging einrichten ==='
    cat <<'EOF_AUDIT' > /etc/audit/rules.d/hardening.rules
# Identitätsdateien überwachen
-w /etc/passwd -p wa -k identity_changes
-w /etc/shadow -p wa -k identity_changes
-w /etc/group -p wa -k identity_changes
-w /etc/sudoers -p wa -k sudo_changes

# PostgreSQL Konfiguration überwachen
-w /etc/postgresql/ -p wa -k pgsql_config_changes
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes
EOF_AUDIT

    augenrules --load || service auditd restart
    systemctl enable auditd

    echo '=== 5. SSH- und Kernel-Hardening (Sysctl) ==='
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config || true
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config || true
    systemctl restart ssh || systemctl restart sshd

    cat <<'EOF_SYSCTL' > /etc/sysctl.d/99-hardening.conf
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
EOF_SYSCTL
    sysctl -p /etc/sysctl.d/99-hardening.conf

    systemctl enable unattended-upgrades
    echo '=== Hardening auf db-vm abgeschlossen ==='
  " \
  --output table

echo -e "\n=========================================================="
echo "   Hardening auf beiden VMs erfolgreich abgeschlossen!"
echo "=========================================================="
