/*
  # Add mt5_token column to user_accounts table

  1. Changes
    - Add `mt5_token` column to `user_accounts` table
    - Column will store MT5 authentication tokens as text
    - Column is nullable to allow existing records without tokens

  2. Security
    - No changes to existing RLS policies needed
    - Column inherits existing table security settings
*/

-- Add mt5_token column to user_accounts table
ALTER TABLE user_accounts ADD COLUMN IF NOT EXISTS mt5_token TEXT;