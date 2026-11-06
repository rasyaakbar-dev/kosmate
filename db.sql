-- ============================================================================
-- 1. ENUMS CREATION
-- ============================================================================
CREATE TYPE public.user_role AS ENUM ('admin', 'owner', 'tenant');
CREATE TYPE public.room_status AS ENUM ('available', 'occupied', 'maintenance', 'unavailable');
CREATE TYPE public.booking_status AS ENUM ('pending', 'approved', 'rejected', 'cancelled');
CREATE TYPE public.payment_status AS ENUM ('pending', 'paid', 'overdue', 'cancelled');
CREATE TYPE public.complaint_category AS ENUM ('maintenance', 'cleanliness', 'noise', 'security', 'other');
CREATE TYPE public.complaint_priority AS ENUM ('low', 'medium', 'high', 'urgent');
CREATE TYPE public.complaint_status AS ENUM ('pending', 'in_progress', 'resolved', 'rejected');

-- ============================================================================
-- 2. TABLES DEFINITIONS
-- ============================================================================

-- Users / Profiles (Bridged with Supabase Auth)
CREATE TABLE public.users (
  user_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  auth_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  name character varying NOT NULL,
  email text NOT NULL UNIQUE CHECK (length(TRIM(BOTH FROM email)) > 0),
  phone character varying NOT NULL,
  role public.user_role NOT NULL DEFAULT 'tenant'::public.user_role,
  avatar_url text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT users_pkey PRIMARY KEY (user_id)
);

-- House / Boarding House
CREATE TABLE public.house (
  house_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  owner_id bigint NOT NULL,
  house_name character varying NOT NULL,
  house_address text NOT NULL,
  description text,
  thumbnail_url text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT house_pkey PRIMARY KEY (house_id),
  CONSTRAINT house_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(user_id) ON DELETE CASCADE
);

-- Room
CREATE TABLE public.room (
  room_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  house_id bigint NOT NULL,
  room_number character varying NOT NULL,
  room_type character varying NOT NULL,
  price numeric NOT NULL CHECK (price >= 0::numeric),
  facilities text,
  image_urls text[],
  status public.room_status NOT NULL DEFAULT 'available'::public.room_status,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT room_pkey PRIMARY KEY (room_id),
  CONSTRAINT room_house_id_fkey FOREIGN KEY (house_id) REFERENCES public.house(house_id) ON DELETE CASCADE
);

-- Booking
CREATE TABLE public.booking (
  booking_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id bigint NOT NULL,
  room_id bigint NOT NULL,
  request_date date NOT NULL DEFAULT CURRENT_DATE,
  status public.booking_status NOT NULL DEFAULT 'pending'::public.booking_status,
  notes text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT booking_pkey PRIMARY KEY (booking_id),
  CONSTRAINT booking_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE,
  CONSTRAINT booking_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.room(room_id) ON DELETE RESTRICT
);

-- Payment
CREATE TABLE public.payment (
  payment_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id bigint NOT NULL,
  room_id bigint NOT NULL,
  amount numeric NOT NULL CHECK (amount >= 0::numeric),
  due_date date NOT NULL,
  status public.payment_status NOT NULL DEFAULT 'pending'::public.payment_status,
  paid_date date,
  receipt_url text,
  order_id text UNIQUE,
  transaction_id text,
  payment_type text,
  qr_code_url text,
  deeplink_url text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT payment_pkey PRIMARY KEY (payment_id),
  CONSTRAINT payment_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE,
  CONSTRAINT payment_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.room(room_id) ON DELETE RESTRICT
);

-- Complaint
CREATE TABLE public.complaint (
  complaint_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id bigint NOT NULL,
  room_id bigint NOT NULL,
  category public.complaint_category NOT NULL,
  title character varying NOT NULL,
  description text NOT NULL,
  priority public.complaint_priority NOT NULL DEFAULT 'medium'::public.complaint_priority,
  date date NOT NULL DEFAULT CURRENT_DATE,
  response text,
  attachment_url text,
  status public.complaint_status NOT NULL DEFAULT 'pending'::public.complaint_status,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT complaint_pkey PRIMARY KEY (complaint_id),
  CONSTRAINT complaint_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE,
  CONSTRAINT complaint_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.room(room_id) ON DELETE RESTRICT
);

-- ==========================================================================
-- 3. INDEXES FOR FOREIGN KEY LOOKUPS
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_booking_user_id ON public.booking (user_id);
CREATE INDEX IF NOT EXISTS idx_booking_room_id ON public.booking (room_id);
CREATE INDEX IF NOT EXISTS idx_complaint_user_id ON public.complaint (user_id);
CREATE INDEX IF NOT EXISTS idx_complaint_room_id ON public.complaint (room_id);
CREATE INDEX IF NOT EXISTS idx_house_owner_id ON public.house (owner_id);
CREATE INDEX IF NOT EXISTS idx_payment_user_id ON public.payment (user_id);
CREATE INDEX IF NOT EXISTS idx_payment_room_id ON public.payment (room_id);
CREATE INDEX IF NOT EXISTS idx_room_house_id ON public.room (house_id);

-- ============================================================================
-- 4. AUTOMATIC PROFILE SYNCHRONIZATION WITH SUPABASE AUTH
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.users (auth_id, name, email, phone, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'New User'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'tenant'::public.user_role)
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES & FUNCTIONS
-- ============================================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.house ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaint ENABLE ROW LEVEL SECURITY;

-- Helper function to fetch current public.user_id and role
CREATE OR REPLACE FUNCTION public.current_user_profile()
RETURNS public.users
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT * FROM public.users WHERE auth_id = auth.uid() LIMIT 1;
$$;

-- Helper function to verify if authenticated caller has admin privileges
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users 
    WHERE auth_id = auth.uid() AND role = 'admin'::public.user_role
  );
$$;

-- Users policies
CREATE POLICY "Users can view all public profiles" ON public.users
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can update their own profile or admin can update any" ON public.users
  FOR UPDATE TO authenticated
  USING (auth_id = auth.uid() OR public.is_admin())
  WITH CHECK (auth_id = auth.uid() OR public.is_admin());

-- House policies (Anyone can read; owners & admins can insert/update/delete)
CREATE POLICY "Houses are viewable by authenticated users" ON public.house
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Owners and admins can manage houses" ON public.house
  FOR ALL TO authenticated
  USING (
    owner_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid()) 
    OR public.is_admin()
  );

-- Room policies (Anyone can view rooms; house owners & admins manage rooms)
CREATE POLICY "Rooms are viewable by authenticated users" ON public.room
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Owners and admins can manage rooms in their houses" ON public.room
  FOR ALL TO authenticated
  USING (
    house_id IN (
      SELECT house_id FROM public.house 
      WHERE owner_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    )
    OR public.is_admin()
  );

-- Booking policies (Tenants see/create their bookings; Owners & admins see/manage bookings)
CREATE POLICY "Tenants can view and create their own bookings" ON public.booking
  FOR ALL TO authenticated
  USING (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    OR public.is_admin()
  )
  WITH CHECK (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "Owners and admins can view and manage bookings for their rooms" ON public.booking
  FOR ALL TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id FROM public.room r
      JOIN public.house h ON r.house_id = h.house_id
      WHERE h.owner_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    )
    OR public.is_admin()
  );

-- Payment policies
CREATE POLICY "Tenants can view and update proof on their payments" ON public.payment
  FOR ALL TO authenticated
  USING (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "Owners and admins can manage payments for their rooms" ON public.payment
  FOR ALL TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id FROM public.room r
      JOIN public.house h ON r.house_id = h.house_id
      WHERE h.owner_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    )
    OR public.is_admin()
  );

-- Complaint policies
CREATE POLICY "Tenants can manage their complaints" ON public.complaint
  FOR ALL TO authenticated
  USING (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "Owners and admins can view and respond to complaints for their rooms" ON public.complaint
  FOR ALL TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id FROM public.room r
      JOIN public.house h ON r.house_id = h.house_id
      WHERE h.owner_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    )
    OR public.is_admin()
  );

-- ============================================================================
-- 6. AUTOMATED ROOM OCCUPANCY TRIGGER ON BOOKING APPROVAL
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_booking_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status = 'approved'::public.booking_status AND OLD.status != 'approved'::public.booking_status THEN
    UPDATE public.room 
    SET status = 'occupied'::public.room_status 
    WHERE room_id = NEW.room_id;
  ELSIF (NEW.status = 'cancelled'::public.booking_status OR NEW.status = 'rejected'::public.booking_status)
        AND OLD.status = 'approved'::public.booking_status THEN
    UPDATE public.room 
    SET status = 'available'::public.room_status 
    WHERE room_id = NEW.room_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_booking_status_change
  AFTER UPDATE OF status ON public.booking
  FOR EACH ROW EXECUTE FUNCTION public.handle_booking_status_change();

-- ============================================================================
-- 7. STORAGE BUCKETS & STORAGE POLICIES
-- ============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('room-images', 'room-images', true),
  ('payment-receipts', 'payment-receipts', true),
  ('complaint-attachments', 'complaint-attachments', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- Fix B: Broad SELECT policies are removed — public buckets serve files via URL without
-- needing a SELECT policy, and listing all file names is an unnecessary data exposure.
-- DROP in case they were previously created on this instance.
DROP POLICY IF EXISTS "Public can view room images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view complaint attachments" ON storage.objects;

-- Storage RLS: Upload policies (kept — only SELECT is removed)
CREATE POLICY "Authenticated users can upload room images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'room-images');

CREATE POLICY "Authenticated users can upload payment receipts" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'payment-receipts');

CREATE POLICY "Authenticated users can upload complaint attachments" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'complaint-attachments');


-- ============================================================================
-- 8. MIDTRANS E-WALLET MIGRATION (Idempotent for existing databases)
-- ============================================================================
ALTER TABLE public.payment 
  ADD COLUMN IF NOT EXISTS order_id text UNIQUE,
  ADD COLUMN IF NOT EXISTS transaction_id text,
  ADD COLUMN IF NOT EXISTS payment_type text,
  ADD COLUMN IF NOT EXISTS qr_code_url text,
  ADD COLUMN IF NOT EXISTS deeplink_url text;

-- ============================================================================
-- 9. SECURITY HARDENIN
-- ============================================================================
-- Trigger-only functions (never callable via PostgREST RPC)
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_booking_status_change() FROM PUBLIC, anon, authenticated;

-- Security invoker helpers (only authenticated users can call)
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

REVOKE ALL ON FUNCTION public.current_user_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_profile() TO authenticated;

-- rls_auto_enable is a dev helper; revoke from PUBLIC, anon, authenticated if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'rls_auto_enable'
  ) THEN
    REVOKE ALL ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;
  END IF;
END;
$$;

