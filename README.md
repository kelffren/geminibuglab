# geminibuglab

Laboratorio aislado para depuración, cirugía y experimentos de Kelo World.

## Regla operativa obligatoria

Antes de modificar este repositorio, cualquier agente debe leer y seguir [`AGENTS.md`](./AGENTS.md).

Metodología oficial:

**Producción intacta → rama experimental en el lab → preview en Pages del LAB → prueba desde iPhone → evidencia → parche mínimo → promoción a producción solo con instrucción explícita del usuario.**

Producción: `kelffren/gemini`

Laboratorio: `kelffren/geminibuglab`

## Pages: separación absoluta

Todo trabajo visual, interactivo, de World Editor, gameplay, UI, input o rendering realizado en una rama experimental debe poder previsualizarse desde el teléfono mediante **GitHub Pages de `kelffren/geminibuglab`**.

Esa preview es exclusivamente del laboratorio.

**PROHIBIDO usar, modificar, repuntar, desactivar o reemplazar GitHub Pages de `kelffren/gemini` para probar trabajo experimental.**

El flujo de Pages debe ser:

```text
geminibuglab/experimental-branch
        ↓
Pages del LAB
        ↓
iPhone / Safari
```

Nunca:

```text
geminibuglab
        ↓
gemini Pages
```

La preview debe indicar claramente `LAB / NOT PRODUCTION`, la rama y el SHA/build probado.

Este repositorio no debe sincronizar cambios automáticamente hacia producción.
