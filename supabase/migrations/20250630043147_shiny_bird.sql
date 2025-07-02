/*
  # Add profit_loss column to trading_signals table

  1. Changes
    - Add `profit_loss` column to `trading_signals` table
    - This allows storing the actual profit or loss of each executed trade
    - Enables accurate profit tracking for trading robots

  2. Security
    - No changes to RLS policies needed
    - Maintains existing access controls
*/

-- Add profit_loss column to trading_signals table
ALTER TABLE trading_signals 
ADD COLUMN IF NOT EXISTS profit_loss numeric(10,2);

-- Add comment to document the purpose
COMMENT ON COLUMN trading_signals.profit_loss IS 'Actual profit or loss of the executed trade.';