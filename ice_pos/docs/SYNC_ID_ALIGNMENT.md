# Alineación de IDs: local = nube

Para que los productos (y categorías, supplies, etc.) tengan **el mismo ID en la nube y en cada dispositivo**, la nube debe ser la única fuente de verdad del menú y todos los dispositivos deben obtener sus datos **solo por sincronización**.

**Regla en la app:** "Cargar desde JSON" solo está permitido cuando la **nube está vacía**. Si la nube ya tiene datos, la opción se bloquea y se indica usar Sincronizar. Así solo un dispositivo (el que sube el menú la primera vez) puede cargar desde JSON; el resto debe usar Sincronizar.

## Por qué a veces los IDs no coinciden

- **Dispositivo A** carga desde JSON → recibe ids locales 1, 2, 3, … (auto-increment).
- **Dispositivo A** hace “Enviar datos a la nube” → la nube guarda esos mismos ids (1, 2, 3, …).
- **Dispositivo B** nunca hace “Sincronizar”: tiene su propia base (por ejemplo de una carga JSON antigua o de otra fuente) con ids distintos (ej. 1800, 1801, 1811, …).
- Al hacer venta en B, la app envía `productId: 1811` a la nube. En la nube ese id no existe o es otro producto → error.

El fallback por nombre existía para poder cobrar aunque el mapa de IDs estuviera desactualizado, pero si quieres **siempre** mismo ID local que en la nube, el flujo debe ser el siguiente.

## Flujo recomendado (mismo ID local y en nube)

### 1. Un solo dispositivo “maestro”

- En ese dispositivo: **Cargar menú desde JSON** (o “Reload menu from JSON”).
- Luego: **Enviar datos a la nube**.
- Ese dispositivo queda con ids locales = ids en la nube (y el mapa guardado es identidad).

### 2. Resto de dispositivos (cajas, tablets, etc.)

- **No** cargar desde JSON en estos dispositivos.
- Solo usar **Sincronizar** desde el menú (≡). Así se reemplaza toda la base local con la de la nube y los ids locales pasan a ser los mismos que en la nube.

### 3. Después de “borrar todo en la nube”

- En el **maestro**: de nuevo **Cargar menú desde JSON** → **Enviar datos a la nube**.
- En los **demás**: **Sincronizar** para volver a alinear ids.

### 4. App recién instalada (dispositivo nuevo)

- No cargar desde JSON.
- Abrir la app y, si la nube ya tiene datos, hacer **Sincronizar** al inicio (o desde el menú). Así el dispositivo nuevo también tendrá los mismos ids que la nube.

## Resumen

| Quién              | Acción                          | Resultado                    |
|--------------------|---------------------------------|-----------------------------|
| Dispositivo maestro| Cargar desde JSON → Enviar nube | Local = nube, mismos IDs    |
| Otros dispositivos | Solo Sincronizar                | Local = nube, mismos IDs    |
| Después de truncar | Maestro: JSON + Enviar; otros: Sincronizar | Todos con mismos IDs |

Si todos siguen este flujo, **no hace falta fallback por nombre**: el mapa local→nube es identidad (mismo id local que en la nube) y las ventas se envían con el id correcto.
