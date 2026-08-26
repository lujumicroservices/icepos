-- Migration: employee prices + discount types
-- Run in Supabase SQL Editor if upgrading an existing database.

alter table public.products
  add column if not exists employee_price real;

alter table public.discounts
  add column if not exists type text not null default 'percentage';
