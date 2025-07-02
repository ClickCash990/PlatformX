-- Add ticket column to trading_signals table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'trading_signals' AND column_name = 'ticket'
  ) THEN
    ALTER TABLE trading_signals ADD COLUMN ticket bigint;
    COMMENT ON COLUMN trading_signals.ticket IS 'Ticket number for targeted position closing';
  END IF;
END $$;

-- Add bot_token column to trading_signals table if it doesn't exist
DO $$
BEGIN
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