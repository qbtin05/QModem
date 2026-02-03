#!/bin/bash
# Script to fix recursive Kconfig dependencies in OpenWrt feeds
# This patches problematic Config.in files after feeds are downloaded

set -e

SDK_DIR="${1:-sdk}"

echo "Fixing recursive Kconfig dependencies in ${SDK_DIR}..."

# Fix 0: PACKAGE_base-files / PACKAGE_busybox-selinux circular dependency
# This happens in Config-build.in where base-files selects busybox-selinux but also depends on it
if [ -f "${SDK_DIR}/Config-build.in" ]; then
    echo "Fixing base-files / busybox-selinux circular dependency..."
    # Remove the 'select PACKAGE_busybox-selinux' from PACKAGE_base-files config
    # More specific pattern to avoid affecting other configs
    sed -i '/^[[:space:]]*config PACKAGE_base-files$/,/^[[:space:]]*config [A-Z]/{
        /^[[:space:]]*select PACKAGE_busybox-selinux$/d
    }' "${SDK_DIR}/Config-build.in" || true
fi

# Fix 1: PACKAGE_busybox / BUSYBOX_CONFIG_PAM circular dependency
# Remove the 'select PACKAGE_busybox' from BUSYBOX_CONFIG_PAM
if [ -f "${SDK_DIR}/feeds/base/package/utils/busybox/config/Config.in" ]; then
    echo "Fixing busybox PAM dependency..."
    sed -i '/config BUSYBOX_CONFIG_PAM/,/^config /{
        /select PACKAGE_busybox/d
    }' "${SDK_DIR}/feeds/base/package/utils/busybox/config/Config.in" || true
fi

# Fix 2: PACKAGE_dovecot / DOVECOT_LDAP circular dependency  
# Change 'depends on PACKAGE_dovecot' to be conditional
if [ -f "${SDK_DIR}/feeds/packages/mail/dovecot/Config.in" ]; then
    echo "Fixing dovecot LDAP dependency..."
    sed -i 's/^\([[:space:]]*\)depends on PACKAGE_dovecot$/\1depends on PACKAGE_dovecot || PACKAGE_dovecot-utils/' \
        "${SDK_DIR}/feeds/packages/mail/dovecot/Config.in" || true
fi

# Fix 3: PACKAGE_postfix / POSTFIX_LDAP circular dependency
if [ -f "${SDK_DIR}/feeds/packages/mail/postfix/Config.in" ]; then
    echo "Fixing postfix LDAP dependency..."
    # Remove the problematic depends line for POSTFIX_LDAP
    sed -i '/config POSTFIX_LDAP/,/^config /{
        /depends on PACKAGE_postfix/d
    }' "${SDK_DIR}/feeds/packages/mail/postfix/Config.in" || true
fi

# Fix 4: LIBCURL_LDAP / PACKAGE_libcurl circular dependency
if [ -f "${SDK_DIR}/feeds/packages/net/curl/Config.in" ]; then
    echo "Fixing libcurl LDAP dependency..."
    sed -i '/config LIBCURL_LDAP/,/^config /{
        /depends on PACKAGE_libcurl/d
    }' "${SDK_DIR}/feeds/packages/net/curl/Config.in" || true
fi

# Fix 5: PACKAGE_NETATALK_LDAP / PACKAGE_netatalk-full circular dependency
if [ -f "${SDK_DIR}/feeds/packages/net/netatalk/Config.in" ]; then
    echo "Fixing netatalk LDAP dependency..."
    sed -i '/config PACKAGE_NETATALK_LDAP/,/^config /{
        /depends on PACKAGE_netatalk-full/d
    }' "${SDK_DIR}/feeds/packages/net/netatalk/Config.in" || true
fi

# Fix 6: MUTT_SASL / PACKAGE_mutt circular dependency
if [ -f "${SDK_DIR}/feeds/packages/mail/mutt/Config.in" ]; then
    echo "Fixing mutt SASL dependency..."
    sed -i '/config MUTT_SASL/,/^config /{
        /depends on PACKAGE_mutt/d
    }' "${SDK_DIR}/feeds/packages/mail/mutt/Config.in" || true
fi

# Fix 7: RSYSLOG_elasticsearch / PACKAGE_rsyslog circular dependency
if [ -f "${SDK_DIR}/feeds/packages/admin/rsyslog/Config.in" ]; then
    echo "Fixing rsyslog elasticsearch dependency..."
    sed -i '/config RSYSLOG_elasticsearch/,/^config /{
        /depends on PACKAGE_rsyslog/d
    }' "${SDK_DIR}/feeds/packages/admin/rsyslog/Config.in" || true
fi

# Fix 8: FWUPD_CURL / PACKAGE_fwupd-libs circular dependency
if [ -f "${SDK_DIR}/feeds/packages/utils/fwupd/Config.in" ]; then
    echo "Fixing fwupd CURL dependency..."
    sed -i '/config FWUPD_CURL/,/^config /{
        /depends on PACKAGE_fwupd-libs/d
    }' "${SDK_DIR}/feeds/packages/utils/fwupd/Config.in" || true
fi

# Fix 9: GENSIO_SSHD / PACKAGE_gensio-bin circular dependency
if [ -f "${SDK_DIR}/feeds/packages/net/gensio/Config-bin.in" ]; then
    echo "Fixing gensio SSHD dependency..."
    sed -i '/config GENSIO_SSHD/,/^config /{
        /depends on PACKAGE_gensio-bin/d
    }' "${SDK_DIR}/feeds/packages/net/gensio/Config-bin.in" || true
fi

# Fix 10: QEMU_UI_VNC_SASL / PACKAGE_qemu-x86_64-softmmu circular dependency
if [ -f "${SDK_DIR}/feeds/packages/utils/qemu/Config.in" ]; then
    echo "Fixing qemu VNC SASL dependency..."
    sed -i '/config QEMU_UI_VNC_SASL/,/^config /{
        /depends on PACKAGE_qemu-x86_64-softmmu/d
    }' "${SDK_DIR}/feeds/packages/utils/qemu/Config.in" || true
fi

# Fix 11: Self-referencing packages (nginx modules, ariang, etebase)
# These are trickier - they reference themselves which is clearly wrong
# We'll just comment out the self-referencing depends lines

for pkg in nginx-mod-luci nginx-mod-lua nginx-mod-brotli nginx-mod-dav-ext \
           nginx-mod-naxsi nginx-mod-rtmp nginx-mod-ts nginx-mod-headers-more \
           ariang-nginx etebase; do
    # Find and store matching files to avoid redundant directory scanning
    mapfile -t config_files < <(find "${SDK_DIR}/feeds/packages" -name "Config*.in" -exec grep -l "PACKAGE_${pkg}" {} \; 2>/dev/null || true)
    
    if [ ${#config_files[@]} -gt 0 ]; then
        echo "Fixing self-referencing package: ${pkg}..."
        for file in "${config_files[@]}"; do
            sed -i "/config PACKAGE_${pkg}/,/^config /{
                /depends on PACKAGE_${pkg}\$/d
            }" "$file" 2>/dev/null || true
        done
    fi
done

# Fix 12: zabbix frontend / php8-mod-mysqli circular dependency
if [ -f "${SDK_DIR}/feeds/packages/admin/zabbix/Config.in" ]; then
    echo "Fixing zabbix frontend mysqli dependency..."
    sed -i '/config PACKAGE_zabbix-frontend-server/,/^config /{
        /select PACKAGE_php8-mod-mysqli/d
    }' "${SDK_DIR}/feeds/packages/admin/zabbix/Config.in" || true
fi

echo "Kconfig dependency fixes applied successfully!"
