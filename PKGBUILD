pkgname=back-man
pkgver=0.2
pkgrel=2
pkgdesc="Experimental utility for managing backup tasks based on config files"
arch=("any")
url="https://github.com/EsGeh/"
license=('GPL')
depends=( \
	'copy-tools=0.4.1' \
)
source=( 'back-man.fish' '__back_man.conf.def')
sha1sums=('SKIP' 'SKIP')

package() {
		dest_dir="/usr/bin"
		echo "dest_dir: $dest_dir"
    mkdir -p "$pkgdir/$dest_dir"
    install -D -m755 ./back-man.fish "$pkgdir/$dest_dir/"
    install -D -m444 ./__back_man.conf.def "$pkgdir/$dest_dir/"
}
