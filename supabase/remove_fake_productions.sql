-- Remove the placeholder production record that was published during setup/testing.
-- Run this in the Supabase SQL editor while logged in as the project owner.

delete from public.productions
where id = '5e39e40b-c668-466f-8e04-33de2a9f3cad'
  and title = 'MS PANEL LASER CUT';
