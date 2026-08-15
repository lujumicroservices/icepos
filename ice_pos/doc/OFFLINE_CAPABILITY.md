# Offline capability and replay policy (ICE POS)

This document defines what works without network and how local data relates to Supabase for the **cloud-first, cache + queue** model.

## Roles

| Layer | Purpose |
|--------|---------|
| **Supabase** | Source of truth when online: catalog, inventory, sales, shifts (within RLS). |
| **Drift (SQLite)** | **Cache** of the last successful catalog snapshot; **queue** for mutations not yet acknowledged by the cloud. |
| **Offline** | Narrow: use cached catalog and queue sales/movements until the device can replay them. |

## Capability matrix

| Feature | Offline | Notes |
|---------|---------|--------|
| POS: browse menu / cart | Yes | From last cached catalog. |
| POS: complete sale | Yes | Stored locally; cloud id filled when replay succeeds. |
| POS: modifiers on sale | Yes | Line-level modifier JSON is stored for accurate cloud replay. |
| Movements (caja/banco) | Yes | Queued with `needs_cloud_sync` until cloud upsert succeeds. |
| Shift open / close | Partial | Depends on existing flows; cloud reconciliation when online. |
| Parked orders | Yes | Local only until restored. |
| Admin: categories/products/supplies | **No** | Requires internet (`OfflineWritePolicy`). |
| Load menu from JSON | **No** | Requires internet for cloud-first admin path. |
| Cloud reports / web admin | **No** | Online only. |
| Pending cashier approvals (web) | Online for push; device resolves via Realtime when online. |

## Stock and replay policy (v1)

1. **Offline sales** deduct stock **locally** immediately (existing behavior).
2. **Replay to cloud** runs `writeSaleToCloud`, which applies cloud-side inventory from **current** cloud `recipes`/`supplies`. If cloud stock is insufficient, the insert/update may fail or go negative depending on server rules; failures are logged and the sale remains queued for retry or manual handling.
3. **Double deduction risk**: Local stock was already reduced offline; cloud applies its own deduction on replay. Local SQLite remains the register’s view; a later `syncFromCloud` refresh aligns **master** supplies from cloud. Operational expectation: replay soon after connectivity returns to minimize drift.
4. **Movements**: Upsert uses stable local id aligned with cloud (`movements.id`); replay is idempotent.

## Cache freshness

- `CloudSyncService.lastSuccessfulCatalogSyncAt` (persisted) indicates when the local catalog cache last matched a successful cloud pull.
- Stale data may be shown while a background refresh runs; POS should remain usable.
