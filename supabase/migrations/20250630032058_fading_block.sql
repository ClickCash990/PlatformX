/*
  # Add unique constraint to user_accounts table

  1. Changes
    - Add unique constraint on (user_id, mt5_username, mt5_server) columns
    - This allows the upsert operation in authStore.ts to work correctly

  2. Security
    - No changes to existing RLS policies
    - Maintains data integrity by preventing duplicate account entries
*/

-- Check if constraint already exists before creating it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'unique_user_mt5_account'
  ) THEN
    -- Add unique constraint to prevent duplicate user account entries
    ALTER TABLE user_accounts 
    ADD CONSTRAINT unique_user_mt5_account 
    UNIQUE (user_id, mt5_username, mt5_server);
    
    RAISE NOTICE 'Created unique constraint unique_user_mt5_account';
  ELSE
    RAISE NOTICE 'Constraint unique_user_mt5_account already exists, skipping creation';
  END IF;
END $$;