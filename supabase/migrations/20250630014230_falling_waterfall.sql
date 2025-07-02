/*
  # Add account_type column to user_accounts table

  1. Changes
    - Add `account_type` column to `user_accounts` table
    - Set default value to 'live' for existing records
    - Add check constraint to ensure valid account types

  2. Security
    - No changes to RLS policies needed
    - Column allows NULL values for flexibility
*/

-- Add account_type column to user_accounts table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_accounts' AND column_name = 'account_type'
  ) THEN
    ALTER TABLE user_accounts ADD COLUMN account_type text DEFAULT 'live';
  END IF;
END $$;

-- Add check constraint to ensure valid account types
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'user_accounts_account_type_check'
  ) THEN
    ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_account_type_check 
    CHECK (account_type IN ('live', 'prop'));
  END IF;
END $$;

-- Update existing records to have 'live' as default account type if NULL
UPDATE user_accounts 
SET account_type = 'live' 
WHERE account_type IS NULL;