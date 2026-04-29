pkgname=vinmail
pkgver=1.0.0
pkgrel=1
pkgdesc="Interactive Bash-based mail client for msmtp with multi-account management and GPG support."
arch=('any')
url="https://github.com/VintellX/vinmail"
license=('MIT')
depends=('bash' 'msmtp' 'vim')
optdepends=(
    'gnupg: GPG password encryption'
    'file: MIME type detection for attachments'
)
source=()
sha256sums=()

package() {
    local repo
    repo="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

    install -Dm755 "$repo/usr/bin/vinmail"               "$pkgdir/usr/bin/vinmail"
    install -Dm644 "$repo/usr/lib/vinmail/core.sh"       "$pkgdir/usr/lib/vinmail/core.sh"
    install -Dm644 "$repo/usr/lib/vinmail/ui.sh"         "$pkgdir/usr/lib/vinmail/ui.sh"
    install -Dm644 "$repo/usr/lib/vinmail/accounts.sh"   "$pkgdir/usr/lib/vinmail/accounts.sh"
    install -Dm644 "$repo/usr/lib/vinmail/compose.sh"    "$pkgdir/usr/lib/vinmail/compose.sh"
    install -Dm644 "$repo/usr/share/vinmail/account.conf.template" \
                                                          "$pkgdir/usr/share/vinmail/account.conf.template"
    install -Dm644 "$repo/usr/share/vinmail/mailrc"      "$pkgdir/usr/share/vinmail/mailrc"
    install -Dm644 "$repo/usr/share/man/man1/vinmail.1"  "$pkgdir/usr/share/man/man1/vinmail.1"
    install -Dm644 "$repo/LICENSE"                       "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
