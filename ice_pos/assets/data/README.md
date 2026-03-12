# Menu data (Reyes Nieves)

## How to load categories and products into the system

### Automatic load on first run

1. **Run the app** (e.g. `flutter run`).
2. On startup, the app runs `DatabaseSeeder(database).seed()`.
3. If there are **no categories** in the database, it loads:
   - **Categories** and **products** from `menu_reyes_nieves.json`.

So: **first time you run the app** (or after a fresh install), the menu is loaded automatically from the JSON file.

### When the menu is not loaded again

- The seeder **skips** loading the menu if **any category already exists**.
- So after the first load, editing the JSON and restarting the app will **not** update the database.

### How to reload the menu (after editing JSON)

**Option A – Force reload from the app (recommended)**  
1. Open the **drawer** (☰) on the Home screen.  
2. Tap **Reload menu from JSON**.  
3. Confirm. The app clears existing categories and menu products, then loads again from `menu_reyes_nieves.json`.

**Option B – Reset the database**  
- Uninstall the app and install again, or  
- Delete the app’s data (e.g. clear app data on the device).  
Then run the app; the full seed (including the menu) runs again.

### Data files (solo JSON)

| File | Use |
|------|-----|
| `menu_reyes_nieves.json` | **Origen del menú.** Categorías y productos. Conos/Vasos/Canastas tienen `items: []`; sus productos vienen de `nieves_modifiers.json`. |
| `menu_reyes_nieves_flavors.json` | Lista de referencia de sabores (para futuros modificadores). |
| `bolis_modifiers.json` | **Boli**: un solo modificador "Sabor" con opciones Regular y Light por sabor; en el POS se muestran agrupadas (sección Regular / Light). Cantidad por sabor. |
| `paletas_modifiers.json` | **Paleta Agua** y **Paleta Forrada** con grupo Sabor. Cargado por el seeder. |
| `nieves_modifiers.json` | **Nieves**: Conos (Mini 2 bolas, Chico 3), Vasos (Mini 2, Chico 3, Mediano 4, Grande 5), Canastas (Mediana 4, Grande 5). Cada sabor es un **insumo en ml**; se descuenta del inventario **50 ml por bola** (quantityDeducted). Stock inicial 5000 ml por sabor. |
| `recetas_formato.json` / `recetas_formato.csv` | **Recetas**: formato para capturar qué insumos y cantidades usa cada producto. Ver [RECETAS_FORMATO.md](RECETAS_FORMATO.md). |

Tras editar cualquier JSON, usa **Reload menu from JSON** (o reinstalar la app) para cargar los cambios.

---

## Bolis y Paletas

### Cómo está dado de alta el Boli

El producto **Boli** no viene del JSON: se crea en el seed con **modifiers** para que el operador elija:

1. **Tipo**: Regular o Light (cada uno con inventario propio: supplies “Boli Regular” y “Boli Light”).
2. **Sabor**: uno de 17 sabores (café, coco, chongos, chocolate, rompope, pistache, piñón, vainilla, fresa, nuez, uva, jamaica, tejuino, limón-hierbabuena, chicle, tamarindo, mango con chile).
3. **Cantidad (piezas)**: en el mismo diálogo, antes de “Agregar al carrito”, el operador puede subir/bajar la cantidad (1–99).

Flujo en POS: el operador toca **Boli** → se abre el diálogo → elige Tipo (Regular o Light) → elige Sabor → ajusta cantidad si quiere → “Agregar al carrito”. En el carrito puede seguir cambiando la cantidad de esa línea.

- **Paleta Agua** y **Paleta Forrada** siguen siendo productos simples en el JSON (sin modifiers); si más adelante quieres “sabor” o “tipo” para paletas, se puede hacer igual que el Boli (producto con modifier groups).
- Después de **Reload menu from JSON**, el seed vuelve a crear el producto Boli con Tipo + Sabor automáticamente.
