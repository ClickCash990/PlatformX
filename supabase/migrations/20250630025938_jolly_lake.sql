/*
  # Fix Policy Conflict Error

  1. Changes
    - Safely create the "Users can manage their own signals" policy only if it doesn't exist
    - This resolves the 400 error: "policy already exists"

  2. Security
    - No changes to existing security model
    - Ensures policy exists without causing errors on repeated migrations
*/

-- Safely create the policy only if it doesn't exist
DO $$
BEGIN
  -- Check if the policy already exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'trading_signals' 
    AND policyname = 'Users can manage their own signals'
  ) THEN
    -- Create the policy if it doesn't exist
    CREATE POLICY "Users can manage their own signals"
      ON trading_signals
      FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
      
    RAISE NOTICE 'Created policy "Users can manage their own signals" for trading_signals table';
  ELSE
    RAISE NOTICE 'Policy "Users can manage their own signals" already exists, skipping creation';
  END IF;
END $$;