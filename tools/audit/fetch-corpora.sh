#!/bin/sh
# Fetches the reference corpora of tools/audit/borrow-audit.py into $CORPORA (default build/corpora, never committed)
# and writes $CORPORA/list.txt (the references, one source file per line) and $CORPORA/allowed.txt (the sources that
# tv3 may use: magiblot/tvision at the commit its translation names, the specification of the far2l extensions, and
# the documents of standards in tools/audit/facts/ of the repository that runs the script).
#   fpc      Free Pascal 3.2.2: packages fv, ide, fcl-base, rtl-objpas, fcl-passrc (GPL / LGPL with exception)
#   fpcmain  the same packages of the main branch of Free Pascal
#   fpide    the Free Pascal IDE on tv3 (unxed/sp, GPL)
#   dn214    DOS Navigator OSP 2.14 sources (licence of RIT Research Labs / DN OSP)
#   dn151    DOS Navigator 1.51 sources (RIT Research Labs)
#   bp7tv    Borland Pascal 7.0 / 7.01 Turbo Vision sources (proprietary)
#   far2l    far2l (C/C++, GPL)
# allowed:
#   magiblot magiblot/tvision @ b4831e2 (C++, MIT)
#   vtexts   VTExts.md, the specification of the far2l terminal extensions (branch extsdocs of unxed/far2l)
# usage: tools/audit/fetch-corpora.sh        needs: git, curl, sha256sum, unrar, unzip
set -eu
here=$(cd "$(dirname "$0")/../.." && pwd)
C=${CORPORA:-$here/build/corpora}
mkdir -p "$C"
cd "$C"

get() {   # get FILE SHA256 URL: download once, check the sha256
    if [ ! -s "$1" ]; then
        curl -fsSL --retry 4 --max-time 900 -o "$1.part" "$3" \
            || curl -fsSL --retry 4 --max-time 900 -o "$1.part" "$(echo "$3" | sed 's|web.archive.org/web/[0-9]*if_/||')"
        mv "$1.part" "$1"
    fi
    echo "$2  $1" | sha256sum -c - >/dev/null || { echo "fetch-corpora: $1: wrong sha256" >&2; exit 1; }
}

if [ ! -d fpc ]; then
    rm -rf fpc.tmp
    git clone -q -c advice.detachedHead=false --depth 1 --branch release_3_2_2 --filter=blob:none --sparse https://github.com/fpc/FPCSource fpc.tmp
    git -C fpc.tmp sparse-checkout set packages/fv packages/ide packages/fcl-base packages/rtl-objpas packages/fcl-passrc
    mv fpc.tmp fpc
fi
if [ ! -d fpcmain ]; then
    rm -rf fpcmain.tmp
    git clone -q --depth 1 --filter=blob:none --sparse https://github.com/fpc/FPCSource fpcmain.tmp
    git -C fpcmain.tmp sparse-checkout set packages/fv packages/ide packages/fcl-base packages/rtl-objpas packages/fcl-passrc
    mv fpcmain.tmp fpcmain
fi
if [ ! -d sp ]; then
    rm -rf sp.tmp && git clone -q --depth 1 https://github.com/unxed/sp sp.tmp && mv sp.tmp sp
fi
if [ ! -d dn214 ]; then
    get dn2s214.rar 4b8feadac86780f615d4b2a7847d81ad41f551c1962c9dd58b721806f36608c3 \
        https://web.archive.org/web/20220202202636if_/http://www.dnosp.com/files/dn2/dn2s214.rar
    rm -rf dn214.tmp && mkdir dn214.tmp && unrar x -y -idq dn2s214.rar dn214.tmp/ && mv dn214.tmp dn214
fi
if [ ! -d dn151 ]; then
    get dn151src.zip d2d12bad4a040e751d5a6f4186a8caabd5ba8b3540e3dc7cab69a58a4f210440 \
        https://web.archive.org/web/20250406173244if_/https://download.ritlabs.com/dn/dn151src.zip
    rm -rf dn151.tmp && unzip -q -o dn151src.zip -d dn151.tmp && mv dn151.tmp dn151
fi
if [ ! -d bp7tv ]; then
    get bp7.rar 1ba6251209ae4a56a4f6ce5926bff0eca815ea53a3dd5f57f779d52d1e1dc2fc \
        'https://web.archive.org/web/20231211134715if_/http://old-dos.ru/dl.php?id=9670'
    rm -rf bp7x bp7tv.tmp && mkdir -p bp7x bp7tv.tmp && unrar x -y -idq bp7.rar bp7x/
    for z in BPASCAL.700/D11/TVSRC.ZIP BPASCAL.700/D11/TVDEMO.ZIP BPASCAL.700/D8/TVFM.ZIP BPASCAL.700/D12/TVDEBUG.ZIP; do
        unzip -q -o -C -j "bp7x/$z" '*.pas' -d bp7tv.tmp
    done
    unzip -q -o -C -j bp7x/_UPDATE_/BP_OBJEC.701/2/BP7ETC.ZIP 'rtl/tv/*.pas' 'rtl/common/objects.pas' -d bp7tv.tmp
    rm -rf bp7x && mv bp7tv.tmp bp7tv
fi
if [ ! -d far2l ]; then
    rm -rf far2l.tmp && git clone -q --depth 1 https://github.com/elfmz/far2l far2l.tmp && mv far2l.tmp far2l
fi
if [ ! -d magiblot ]; then
    rm -rf magiblot.tmp
    git clone -q --filter=blob:none --no-checkout https://github.com/magiblot/tvision magiblot.tmp
    git -C magiblot.tmp -c advice.detachedHead=false checkout -q b4831e2
    mv magiblot.tmp magiblot
fi
if [ ! -s VTExts.md ]; then
    curl -fsSL --retry 4 -o VTExts.md.part https://raw.githubusercontent.com/unxed/far2l/extsdocs/VTExts.md
    mv VTExts.md.part VTExts.md
fi

{
    find far2l -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \)
    find fpc/packages fpcmain/packages -type f \( -iname '*.pas' -o -iname '*.pp' -o -iname '*.inc' \)
    find sp/fpide -type f \( -iname '*.pas' -o -iname '*.pp' -o -iname '*.inc' \)
    find dn214 dn151 bp7tv -type f \( -iname '*.pas' -o -iname '*.pp' -o -iname '*.inc' \)
} | LC_ALL=C sort | sed "s|^|$C/|" > list.txt
{
    find magiblot/source magiblot/include -type f \( -name '*.cpp' -o -name '*.h' \) | sed "s|^|$C/|"
    echo "$C/VTExts.md"
    find "$here/tools/audit/facts" -type f -name '*.md' 2>/dev/null
} | LC_ALL=C sort > allowed.txt
echo "reference corpora: $(wc -l < list.txt) files in $C; allowed sources: $(wc -l < allowed.txt)"
