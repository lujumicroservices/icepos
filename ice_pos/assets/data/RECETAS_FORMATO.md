# Formato para capturar recetas de productos

Los archivos `recetas_formato.json` y `recetas_formato.csv` vienen con **todos los productos del menú ya listados** (ingredientes vacíos). Solo tienes que completar la lista de insumos y cantidades para cada producto.

**Guía de insumos:** Para localizar rápido un insumo y ver la **unidad de medida** (pcs, lt, kg) que debes usar en la receta, usa **[insumos_guia.md](insumos_guia.md)** (o **insumos_guia.csv** en Excel). Orden alfabético.

Las **recetas** en el sistema vinculan cada **producto** del menú con los **insumos** que consume y la **cantidad** por unidad vendida. Sirven para:

- Calcular el **costo** del producto (precio de costo según insumos).
- Descontar **inventario** al registrar una venta (si está habilitado).

---

## Estructura de datos (en la app)

En la base de datos, una receta es:

| Campo              | Descripción                                      |
|--------------------|--------------------------------------------------|
| `product_id`       | ID del producto (ej. Latte Mediano).             |
| `supply_id`        | ID del insumo (ej. Leche, Café Molido).          |
| `quantity_required`| Cantidad de ese insumo **por una unidad** del producto. |

La **unidad** del insumo (kg, lt, pcs) está definida en el catálogo de **Insumos**, no en la receta.

---

## Formato JSON (`recetas_formato.json`)

Estructura pensada para documentar o importar recetas usando **nombres** (producto e insumo) en lugar de IDs.

```json
{
  "recetas": [
    {
      "producto": "Nombre exacto del producto en la app",
      "modificadores": {
        "grupo": "Nombre del grupo (ej. Sabores Elige 2 bolas)",
        "bolas": 2,
        "descuento_por_bola": { "unidad": "ml", "cantidad": 50 },
        "nota": "Se deduce del insumo elegido. Ver insumos_guia."
      },
      "ingredientes": [
        { "insumo": "Nombre exacto del insumo", "cantidad": 0.5 },
        { "insumo": "Otro insumo", "cantidad": 1 }
      ]
    }
  ]
}
```

- **producto**: debe coincidir exactamente con el nombre del producto en **Gestión de productos**.
- **modificadores** (opcional): referencia para el empleado. Indica que el producto tiene opciones (ej. sabores de nieve) y que **además de los ingredientes base** se descuenta del inventario la cantidad indicada por cada elección (ej. 50 ml por cada bola). Así se evita confusión: lo que ves en "ingredientes" es la receta base; el descuento por modificador es automático en la app. Solo productos con modificador (nieves, etc.) llevan este bloque.
- **ingredientes**: lista de insumos y cantidades de la receta base.
- **insumo**: debe coincidir exactamente con el nombre del insumo en **Insumos**.
- **cantidad**: número (entero o decimal). Es la cantidad **por una unidad** del producto, en la unidad del insumo (ej. si el insumo está en kg, 0.25 = 250 g por unidad de producto).

Puedes añadir `"_comentario"` en cualquier receta para notas (se ignora al importar).

---

## Formato CSV (`recetas_formato.csv`) – Excel

Para editar en Excel o Google Sheets. Una **fila por línea de receta** (un producto + un insumo + cantidad).

| producto | insumo | cantidad |
|----------|--------|----------|
| Latte Mediano | Café Molido | 0.018 |
| Latte Mediano | Leche | 0.25 |
| Latte Mediano | Vaso Mediano | 1 |

- **producto**: nombre del producto (igual que en la app).
- **insumo**: nombre del insumo (igual que en Insumos).
- **cantidad**: cantidad requerida por unidad de producto (decimal con punto, ej. `0.25`).

Si el mismo producto usa varios insumos, repite el nombre del producto en varias filas (una por insumo). El CSV precargado tiene una fila por producto con insumo y cantidad vacíos; añade filas con el mismo nombre de producto para cada ingrediente.

---

## Cómo cargar las recetas en la app

1. **Desde la app (recomendado)**  
   - **Menú** → **Productos** → elegir producto → **Editar**.  
   - En la sección **Receta**, agregar cada insumo y su cantidad.  
   - Los nombres deben coincidir con los de tus productos e insumos ya dados de alta.

2. **Desde los archivos de formato**  
   - Usa `recetas_formato.json` o `recetas_formato.csv` como plantilla.  
   - Completa o ajusta producto, insumo y cantidad.  
   - Por ahora no hay “Importar recetas desde archivo” en la app; estos archivos sirven para **capturar y documentar** las recetas y luego cargarlas a mano en la app, o como base para un importador futuro.

---

## Ejemplos de unidades (en Insumos)

| Insumo típico   | Unidad | Ejemplo en receta      |
|-----------------|--------|-------------------------|
| Leche, Agua     | lt     | 0.25 = 250 ml por unidad |
| Café, Nieve     | kg     | 0.018 = 18 g por unidad  |
| Vasos, Conos    | pcs    | 1 = una pieza por unidad  |
| Pajillas        | pcs    | 1                        |

Así puedes mantener un solo archivo de recetas (JSON o CSV) y usarlo como referencia al dar de alta o editar recetas en la app.
