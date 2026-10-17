#!/usr/bin/env bash
# Instala os APKs publicados num emulador Android, abre cada app e guarda
# o que aconteceu: resultado da instalação, foto da tela e o log do Android.
mkdir -p diagnostico
adb shell getprop ro.build.version.release > diagnostico/android.txt 2>&1
adb shell getprop ro.product.cpu.abi >> diagnostico/android.txt 2>&1
for app in motorista gestor; do
  apk=$(ls apks/*.apk | grep -i "$app")
  pkg="br.com.fortalezadigitalsecurity.gestaofrota.$app"
  echo "== $app ($apk)" | tee -a diagnostico/resumo.txt
  adb install -r "$apk" 2>&1 | tee diagnostico/$app-instalar.txt | tail -1 | tee -a diagnostico/resumo.txt
  adb logcat -c
  adb shell am start -W -n "$pkg/$pkg.MainActivity" 2>&1 | tee diagnostico/$app-abrir.txt | tee -a diagnostico/resumo.txt
  for s in 5 15 30; do
    sleep $([ $s = 5 ] && echo 5 || echo 10)
    [ $s = 30 ] && sleep 5
    adb exec-out screencap -p > diagnostico/$app-${s}s.png
    echo "pid depois de ${s}s: $(adb shell pidof $pkg)" | tee -a diagnostico/resumo.txt
  done
  adb logcat -d > diagnostico/$app-logcat.txt
  grep -E "FATAL|AndroidRuntime|flutter|E/|Exception|Error" diagnostico/$app-logcat.txt | grep -v "^--------- beginning" | head -150 > diagnostico/$app-erros.txt
  adb shell am force-stop "$pkg"
done

# Confere: cada app escreveu FROTA_ABRIU (primeira tela apareceu) e não teve
# erro sem tratamento na abertura.
FALHOU=0
for app in motorista gestor; do
  if grep -q "FROTA_ABRIU $app" diagnostico/$app-logcat.txt && ! grep -q "Unhandled Exception" diagnostico/$app-logcat.txt; then
    echo "ok: o app $app abriu" | tee -a diagnostico/resumo.txt
  else
    echo "FALHOU: o app $app não abriu" | tee -a diagnostico/resumo.txt
    grep -m 3 "Unhandled Exception" diagnostico/$app-logcat.txt | cut -c1-400 | tee -a diagnostico/resumo.txt
    FALHOU=1
  fi
done
exit $FALHOU
