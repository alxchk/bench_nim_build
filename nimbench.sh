#!/usr/bin/env bash

DIR=benchnim

rm -rf $HOME/.cache/nim/{koch_d,nim_r,nimble_r,nimgrep_r,nimpretty_r,nimsuggest_r,testament_r}

collectinfo() {
  OS=$(uname)
  [[ $OS == "Linux" ]] && {
    awk -F: '/model name/ {name=$2} END {print "CPU:" name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//'
    awk -F: '/model name/ {core++} END {print "Cores: " core}' /proc/cpuinfo
    awk -F: ' /cpu MHz/ {freq=$2} END {print "Freq:" freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//'
    free -h | awk 'NR==2 {print "Ram: " $2}'
    echo "Disk:" `lsblk -n -d -o VENDOR,MODEL | grep -v '^[[:space:]]*$' | head -n1`
    echo "OS: $OS (`uname -r`)"
  } || {
    echo 'CPU:' `sysctl -n machdep.cpu.brand_string`
    echo 'Cores:' `sysctl -n hw.ncpu`
    FREQ=`sysctl -n hw.cpufrequency`
    [[ -n $FREQ ]] && echo 'Freq:' $(($FREQ / 1000000))
    echo 'RAM:' `sysctl -n hw.physmem`
    diskutil info disk0 | grep 'Device / Media' | awk -F ':' '{gsub(/^[ \t]+/, "", $2); print "Disk: " $2}'
    echo "OS: $OS (`uname -r`)"
  }
}

bench_cmd() {
  (
    echo Benching $@
    export CC=clang
    export TIMEFORMAT="%3R seconds: $*"
    cd Nim && ( time $@ 2>&3 ) 3>&2 2>>../time.log
  ) || { echo Error during build; exit 1; }
}

complete() {
  cat >complete.nim <<'EEE'
import browsers, uri, strformat, strutils, sequtils
let lines = toSeq(lines("time.log")).deduplicate()
echo lines.join("\n")
let title = lines.filterIt(it.startsWith("CPU:")).join().encodeUrl()
let body = ("```\n" & lines.join("\n") & "\n```").encodeUrl()
let url = fmt"https://github.com/inv2004/bench_nim_build/issues/new?title={title}&labels=stats&body={body}"
echo "Please open in your browser the following link if browser is not open:"
echo url
openDefaultBrowser(url)
EEE

grep -i microsoft /proc/version && { export BROWSER=wslview; }
./Nim/bin/nim c -r complete.nim

}

mkdir -p $DIR
(
  cd $DIR && \
  collectinfo > time.log
  [[ ! -d NimCloned ]] && (
    git clone https://github.com/nim-lang/Nim NimCloned && \
    cd NimCloned && \
    git reset --hard fac5bae7b7d87aeec48c7252029c2852ee157ac9 && \
    sed -i -e 's@./koch boot@./koch boot --cc:clang@' ./build_all.sh && \
    sed -i -e 's@./koch tools@./koch tools --cc:clang@' ./build_all.sh && \
    source ci/funs.sh && \
    nimDefineVars && \
    echo_run git clone -q --depth 1 $nim_csourcesUrl "$nim_csourcesDir" && \
    echo_run git -C "$nim_csourcesDir" checkout $nim_csourcesHash
  )

  [[ -d Nim ]] && rm -rf Nim
  cp -r NimCloned Nim && \
  bench_cmd ./build_all.sh CC=clang && \
  bench_cmd ./koch temp -d:release --cc:clang

  echo Delete $DIR folder manualy if you want to cleanup artefacts of the benchmark

  complete
)
