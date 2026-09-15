# geminibuglab

Laboratorio aislado para depuración, cirugía y experimentos de Kelo World.

## Regla operativa obligatoria

Antes de modificar este repositorio, cualquier agente debe leer y seguir [`AGENTS.md`](./AGENTS.md).

Metodología oficial:

**Producción intacta → rama experimental en el lab → preview móvil separada → prueba → evidencia → parche mínimo → promoción a producción solo con instrucción explícita del usuario.**

Producción: `kelffren/gemini`

Laboratorio: `kelffren/geminibuglab`

Este repositorio no debe sincronizar cambios automáticamente hacia producción.
