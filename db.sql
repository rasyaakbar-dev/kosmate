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

-- ============================================================================
-- 3. AUTOMATIC PROFILE SYNCHRONIZATION WITH SUPABASE AUTH
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.house ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaint ENABLE ROW LEVEL SECURITY;

-- Helper function to fetch current public.user_id and role
CREATE OR REPLACE FUNCTION public.current_user_profile()
RETURNS public.users AS $$
  SELECT * FROM public.users WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Users policies
CREATE POLICY "Users can view all public profiles" ON public.users
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can update their own profile" ON public.users
  FOR UPDATE TO authenticated
  USING (auth_id = auth.uid())
  WITH CHECK (auth_id = auth.uid());

-- House policies (Anyone can read; owners can insert/update their houses)
CREATE POLICY "Houses are viewable by authenticated users" ON public.house
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Owners can manage their houses" ON public.house
  FOR ALL TO authenticated
  USING (owner_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid()));

-- Room policies (Anyone can view rooms; house owners manage rooms)
CREATE POLICY "Rooms are viewable by authenticated users" ON public.room
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Owners can manage rooms in their houses" ON public.room
  FOR ALL TO authenticated
  USING (
    house_id IN (
      SELECT house_id FROM public.house 
      WHERE owner_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    )
  );

-- Booking policies (Tenants see/create their bookings; Owners see bookings for their rooms)
CREATE POLICY "Tenants can view and create their own bookings" ON public.booking
  FOR ALL TO authenticated
  USING (user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid()))
  WITH CHECK (user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid()));

CREATE POLICY "Owners can view and manage bookings for their rooms" ON public.booking
  FOR ALL TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id FROM public.room r
      JOIN public.house h ON r.house_id = h.house_id
      WHERE h.owner_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    )
  );

-- Payment policies
CREATE POLICY "Tenants can view and update proof on their payments" ON public.payment
  FOR ALL TO authenticated
  USING (user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid()));

CREATE POLICY "Owners can manage payments for their rooms" ON public.payment
  FOR ALL TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id FROM public.room r
      JOIN public.house h ON r.house_id = h.house_id
      WHERE h.owner_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    )
  );

-- Complaint policies
CREATE POLICY "Tenants can manage their complaints" ON public.complaint
  FOR ALL TO authenticated
  USING (user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid()));

CREATE POLICY "Owners can view and respond to complaints for their rooms" ON public.complaint
  FOR ALL TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id FROM public.room r
      JOIN public.house h ON r.house_id = h.house_id
      WHERE h.owner_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    )
  );