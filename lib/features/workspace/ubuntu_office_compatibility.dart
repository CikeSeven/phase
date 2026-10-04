/// Ubuntu's splash launcher requires /proc/version, which Android restricts
/// even with /proc bound. Keep package-owned launchers intact and expose the
/// headless executable through /usr/local/bin, ahead of /usr/bin in PATH.
abstract final class UbuntuOfficeCompatibility {
  static const configureCommand = r'''
set -eu
if [ ! -x /usr/lib/libreoffice/program/soffice.bin ]; then
  printf 'LibreOffice headless executable is missing\n' >&2
  exit 1
fi
install -d /usr/local/bin
cat > phase-libreoffice <<'PHASE_LIBREOFFICE'
#!/bin/sh
# Bypass oosplash's Android-incompatible /proc/version probe.
export SAL_ENABLE_FILE_LOCKING=1
exec /usr/lib/libreoffice/program/soffice.bin --headless "$@"
PHASE_LIBREOFFICE
temporary=
trap 'if [ -n "$temporary" ]; then rm -f -- "$temporary"; fi' EXIT
trap 'exit 1' HUP INT TERM
for command in libreoffice soffice; do
  temporary=$(mktemp /usr/local/bin/.phase-office-XXXXXX)
  install -m 755 phase-libreoffice "$temporary"
  mv -fT -- "$temporary" "/usr/local/bin/$command"
  temporary=
done
''';
}
