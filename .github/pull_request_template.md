## Qué cambia

<!-- Resumen en una o dos frases. -->

## Por qué

<!-- Qué problema resuelve o qué necesidad cubre. -->

## Cómo se verificó

<!-- Comandos ejecutados y resultado. No basta con "debería funcionar". -->

```bash
docker compose up -d --build
docker exec ubuntu-lab systemctl is-system-running   # running
```

## Checklist

- [ ] El lab se levanta desde cero: `docker compose down -v && docker compose up -d --build`
- [ ] `README.md` actualizado (si cambia el uso, los requisitos o los puertos)
- [ ] `pasos.md` actualizado (si hay comandos nuevos o modificados)
- [ ] `CLAUDE.md` actualizado (si aparece algún *gotcha* nuevo)
- [ ] `memory.md` actualizado (si es un hito para el portafolio)
- [ ] **Revisado el contenido ya existente**, no solo añadidas secciones nuevas:
      ningún comando documentado quedó obsoleto
- [ ] El CI está en verde
