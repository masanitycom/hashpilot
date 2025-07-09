-- First, let's disable the trigger temporarily to clean up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Clean up any duplicate or problematic records
DELETE FROM users WHERE user_id IS NULL OR user_id = '';

-- Recreate the trigger function with better error handling
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    random_user_id text;
    existing_user_count integer;
BEGIN
    -- Check if user already exists in our users table
    SELECT COUNT(*) INTO existing_user_count 
    FROM public.users 
    WHERE id = new.id;
    
    -- If user already exists, don't create another record
    IF existing_user_count > 0 THEN
        RETURN new;
    END IF;
    
    -- Generate a unique 6-character user_id
    LOOP
        random_user_id := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 6));
        
        -- Check if this user_id already exists
        SELECT COUNT(*) INTO existing_user_count 
        FROM public.users 
        WHERE user_id = random_user_id;
        
        -- If unique, break the loop
        IF existing_user_count = 0 THEN
            EXIT;
        END IF;
    END LOOP;
    
    -- Insert the new user record
    INSERT INTO public.users (id, user_id, email, total_purchases, total_referral_earnings, is_active)
    VALUES (new.id, random_user_id, COALESCE(new.email, ''), 0, 0, true);
    
    RETURN new;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error but don't fail the auth process
        RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
        RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
