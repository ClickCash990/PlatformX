/*
  # Promo Codes System

  1. New Tables
    - `promo_codes` - Stores promotional codes for token discounts
      - `id` (uuid, primary key)
      - `code` (text, unique)
      - `discount_percent` (integer)
      - `max_uses` (integer)
      - `used_count` (integer)
      - `expires_at` (timestamp)
      - `is_active` (boolean)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `promo_codes` table
    - Add policy for authenticated users to view active promo codes

  3. Functions
    - `validate_promo_code` - Validates a promo code and returns discount info
    - `use_promo_code` - Increments the used count for a promo code
*/

-- Create promo_codes table
CREATE TABLE IF NOT EXISTS promo_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  discount_percent integer NOT NULL CHECK (discount_percent > 0 AND discount_percent <= 100),
  max_uses integer NOT NULL DEFAULT 100,
  used_count integer NOT NULL DEFAULT 0,
  expires_at timestamptz,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE promo_codes ENABLE ROW LEVEL SECURITY;

-- Create policy for authenticated users to view active promo codes
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'promo_codes' 
    AND policyname = 'Users can view active promo codes'
  ) THEN
    CREATE POLICY "Users can view active promo codes"
      ON promo_codes
      FOR SELECT
      TO authenticated
      USING (
        is_active = true AND 
        (expires_at IS NULL OR expires_at > now()) AND
        used_count < max_uses
      );
      
    RAISE NOTICE 'Created policy "Users can view active promo codes" for promo_codes table';
  ELSE
    RAISE NOTICE 'Policy "Users can view active promo codes" already exists, skipping creation';
  END IF;
END $$;

-- Create trigger for updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_promo_codes_updated_at'
  ) THEN
    CREATE TRIGGER update_promo_codes_updated_at
      BEFORE UPDATE ON promo_codes
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
      
    RAISE NOTICE 'Created trigger "update_promo_codes_updated_at" for promo_codes table';
  ELSE
    RAISE NOTICE 'Trigger "update_promo_codes_updated_at" already exists, skipping creation';
  END IF;
END $$;

-- Create index for faster code lookups
CREATE INDEX IF NOT EXISTS idx_promo_codes_code ON promo_codes(code);

-- Function to validate a promo code
CREATE OR REPLACE FUNCTION validate_promo_code(code_to_check text)
RETURNS TABLE (
  is_valid boolean,
  discount_percent integer,
  message text
) 
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    CASE 
      WHEN p.id IS NULL THEN false
      WHEN p.is_active = false THEN false
      WHEN p.expires_at IS NOT NULL AND p.expires_at < now() THEN false
      WHEN p.used_count >= p.max_uses THEN false
      ELSE true
    END as is_valid,
    COALESCE(p.discount_percent, 0) as discount_percent,
    CASE 
      WHEN p.id IS NULL THEN 'Promo code not found'
      WHEN p.is_active = false THEN 'Promo code is inactive'
      WHEN p.expires_at IS NOT NULL AND p.expires_at < now() THEN 'Promo code has expired'
      WHEN p.used_count >= p.max_uses THEN 'Promo code has reached maximum uses'
      ELSE 'Promo code is valid'
    END as message
  FROM promo_codes p
  WHERE p.code = UPPER(code_to_check)
  LIMIT 1;
  
  -- If no rows returned, return invalid result
  IF NOT FOUND THEN
    RETURN QUERY SELECT 
      false as is_valid,
      0 as discount_percent,
      'Promo code not found' as message;
  END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION validate_promo_code(text) TO authenticated;

-- Function to use a promo code (increment used_count)
CREATE OR REPLACE FUNCTION use_promo_code(code_to_use text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  promo_id uuid;
  is_valid boolean;
BEGIN
  -- First validate the promo code
  SELECT p.id, 
    CASE 
      WHEN p.is_active = true 
        AND (p.expires_at IS NULL OR p.expires_at > now())
        AND p.used_count < p.max_uses
      THEN true
      ELSE false
    END
  INTO promo_id, is_valid
  FROM promo_codes p
  WHERE p.code = UPPER(code_to_use)
  LIMIT 1;
  
  -- If promo code is valid, increment used_count
  IF promo_id IS NOT NULL AND is_valid THEN
    UPDATE promo_codes
    SET 
      used_count = used_count + 1,
      updated_at = now()
    WHERE id = promo_id;
    
    RETURN true;
  ELSE
    RETURN false;
  END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION use_promo_code(text) TO authenticated;

-- Insert some sample promo codes
INSERT INTO promo_codes (code, discount_percent, max_uses, expires_at, is_active)
VALUES 
  ('WELCOME25', 25, 1000, now() + interval '30 days', true),
  ('SUMMER50', 50, 100, now() + interval '14 days', true),
  ('VIP75', 75, 10, now() + interval '7 days', true)
ON CONFLICT (code) DO NOTHING;