/*
  # Fix Schema Issues Migration

  1. Changes
    - Ensure account_type column exists in user_accounts table
    - Ensure mt5_token column exists in user_accounts table
    - Ensure bot_token column exists in trading_robots table
    - Ensure ticket and bot_token columns exist in trading_signals table
    - Add proper constraints and indexes

  2. Security
    - No changes to RLS policies
    - Maintains existing access controls
*/

-- Fix user_accounts table
DO $$
BEGIN
  -- Add account_type column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_accounts' AND column_name = 'account_type'
  ) THEN
    ALTER TABLE user_accounts ADD COLUMN account_type text DEFAULT 'live';
    
    -- Add comment to document the purpose
    COMMENT ON COLUMN user_accounts.account_type IS 'Type of MT5 account: live or prop firm account';
  END IF;

  -- Add check constraint to ensure valid account types
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'user_accounts_account_type_check'
  ) THEN
    ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_account_type_check 
    CHECK (account_type IN ('live', 'prop'));
  END IF;

  -- Update existing records to have 'live' as default account type if NULL
  UPDATE user_accounts 
  SET account_type = 'live' 
  WHERE account_type IS NULL;

  -- Add mt5_token column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_accounts' AND column_name = 'mt5_token'
  ) THEN
    ALTER TABLE user_accounts ADD COLUMN mt5_token TEXT;
    
    -- Add comment to document the purpose
    COMMENT ON COLUMN user_accounts.mt5_token IS 'MT5 API token for webhook automation';
  END IF;
END $$;

-- Fix trading_robots table
DO $$
BEGIN
  -- Add bot_token column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'trading_robots' AND column_name = 'bot_token'
  ) THEN
    ALTER TABLE trading_robots ADD COLUMN bot_token TEXT;
    
    -- Generate unique bot tokens for existing robots
    UPDATE trading_robots 
    SET bot_token = 'bot_' || replace(gen_random_uuid()::text, '-', '')
    WHERE bot_token IS NULL;
    
    -- Add comment to document the purpose
    COMMENT ON COLUMN trading_robots.bot_token IS 'Unique token for this robot to receive targeted webhook signals';
    
    -- Create index for faster lookups
    CREATE INDEX IF NOT EXISTS idx_trading_robots_bot_token ON trading_robots(bot_token);
    
    -- Add unique constraint to ensure bot tokens are unique
    ALTER TABLE trading_robots ADD CONSTRAINT unique_bot_token UNIQUE (bot_token);
  END IF;
END $$;

-- Fix trading_signals table
DO $$
BEGIN
  -- Add ticket column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'trading_signals' AND column_name = 'ticket'
  ) THEN
    ALTER TABLE trading_signals ADD COLUMN ticket bigint;
    COMMENT ON COLUMN trading_signals.ticket IS 'Ticket number for targeted position closing';
  END IF;

  -- Add bot_token column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'trading_signals' AND column_name = 'bot_token'
  ) THEN
    ALTER TABLE trading_signals ADD COLUMN bot_token text;
    COMMENT ON COLUMN trading_signals.bot_token IS 'Bot token that should process this signal';
    
    -- Create index for faster lookups
    CREATE INDEX IF NOT EXISTS idx_trading_signals_bot_token ON trading_signals(bot_token);
  END IF;
END $$;

-- Verify and fix unique constraint on user_accounts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'unique_user_mt5_account' AND table_name = 'user_accounts'
  ) THEN
    ALTER TABLE user_accounts ADD CONSTRAINT unique_user_mt5_account 
    UNIQUE (user_id, mt5_username, mt5_server);
  END IF;
END $$;

-- Create function to validate database schema
CREATE OR REPLACE FUNCTION validate_schema()
RETURNS text AS $$
DECLARE
  issues text := '';
BEGIN
  -- Check user_accounts columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_accounts' AND column_name = 'account_type') THEN
    issues := issues || 'Missing account_type column in user_accounts table. ';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_accounts' AND column_name = 'mt5_token') THEN
    issues := issues || 'Missing mt5_token column in user_accounts table. ';
  END IF;
  
  -- Check trading_robots columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'trading_robots' AND column_name = 'bot_token') THEN
    issues := issues || 'Missing bot_token column in trading_robots table. ';
  END IF;
  
  -- Check trading_signals columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'trading_signals' AND column_name = 'bot_token') THEN
    issues := issues || 'Missing bot_token column in trading_signals table. ';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'trading_signals' AND column_name = 'ticket') THEN
    issues := issues || 'Missing ticket column in trading_signals table. ';
  END IF;
  
  -- Return result
  IF issues = '' THEN
    RETURN 'Schema validation successful. All required columns exist.';
  ELSE
    RETURN 'Schema validation issues: ' || issues;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Run validation and log result
DO $$
DECLARE
  validation_result text;
BEGIN
  validation_result := validate_schema();
  RAISE NOTICE '%', validation_result;
END $$;