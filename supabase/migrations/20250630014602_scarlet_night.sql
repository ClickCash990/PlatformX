/*
  # Add bot_token column to trading_robots table

  1. Changes
    - Add `bot_token` column to `trading_robots` table
    - Set it as TEXT type, nullable initially
    - Add index for performance when querying by bot_token
    - Update existing robots with generated bot tokens

  2. Security
    - No RLS changes needed as existing policies will cover the new column
*/

-- Add the bot_token column to trading_robots table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'trading_robots' AND column_name = 'bot_token'
  ) THEN
    ALTER TABLE trading_robots ADD COLUMN bot_token TEXT;
    
    -- Add index for performance when querying by bot_token
    CREATE INDEX IF NOT EXISTS idx_trading_robots_bot_token ON trading_robots(bot_token);
    
    -- Generate unique bot tokens for existing robots
    UPDATE trading_robots 
    SET bot_token = 'bot_' || replace(gen_random_uuid()::text, '-', '')
    WHERE bot_token IS NULL;
    
    -- Make the column NOT NULL after updating existing records
    ALTER TABLE trading_robots ALTER COLUMN bot_token SET NOT NULL;
    
    -- Add unique constraint to ensure bot tokens are unique
    ALTER TABLE trading_robots ADD CONSTRAINT unique_bot_token UNIQUE (bot_token);
  END IF;
END $$;