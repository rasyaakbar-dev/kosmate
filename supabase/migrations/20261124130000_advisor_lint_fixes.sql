CREATE OR REPLACE FUNCTION public.update_overdue_payments()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_updated integer;
BEGIN
  UPDATE public.payment
  SET status = 'overdue'::public.payment_status
  WHERE status = 'pending'::public.payment_status
    AND due_date < CURRENT_DATE;
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated;
END;
$$;

REVOKE ALL ON FUNCTION public.update_overdue_payments()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_overdue_payments() TO service_role;

DROP POLICY IF EXISTS "Public can view avatars" ON storage.objects;

DROP POLICY IF EXISTS "Users can update their own profile or admin can update any"
  ON public.users;
CREATE POLICY "Users can update their own profile or admin can update any"
  ON public.users
  FOR UPDATE TO authenticated
  USING (
    auth_id = (SELECT auth.uid())
    OR (SELECT public.is_admin())
  )
  WITH CHECK (
    auth_id = (SELECT auth.uid())
    OR (SELECT public.is_admin())
  );

DROP POLICY IF EXISTS "Users can delete their own profile or admin can delete any"
  ON public.users;
CREATE POLICY "Users can delete their own profile or admin can delete any"
  ON public.users
  FOR DELETE TO authenticated
  USING (
    auth_id = (SELECT auth.uid())
    OR (SELECT public.is_admin())
  );

DROP POLICY IF EXISTS "Owners and admins can manage houses" ON public.house;

CREATE POLICY "Owners and admins can insert houses"
  ON public.house
  FOR INSERT TO authenticated
  WITH CHECK (
    owner_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Owners and admins can update houses"
  ON public.house
  FOR UPDATE TO authenticated
  USING (
    owner_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR (SELECT public.is_admin())
  )
  WITH CHECK (
    owner_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Owners and admins can delete houses"
  ON public.house
  FOR DELETE TO authenticated
  USING (
    owner_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR (SELECT public.is_admin())
  );

DROP POLICY IF EXISTS "Owners and admins can manage rooms in their houses"
  ON public.room;

CREATE POLICY "Owners and admins can insert rooms"
  ON public.room
  FOR INSERT TO authenticated
  WITH CHECK (
    house_id IN (
      SELECT h.house_id
      FROM public.house h
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Owners and admins can update rooms"
  ON public.room
  FOR UPDATE TO authenticated
  USING (
    house_id IN (
      SELECT h.house_id
      FROM public.house h
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  )
  WITH CHECK (
    house_id IN (
      SELECT h.house_id
      FROM public.house h
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Owners and admins can delete rooms"
  ON public.room
  FOR DELETE TO authenticated
  USING (
    house_id IN (
      SELECT h.house_id
      FROM public.house h
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

DROP POLICY IF EXISTS "Tenants can view their own bookings" ON public.booking;
DROP POLICY IF EXISTS "Tenants can create pending bookings" ON public.booking;
DROP POLICY IF EXISTS "Tenants can cancel their own bookings" ON public.booking;
DROP POLICY IF EXISTS "Owners can view bookings for their rooms" ON public.booking;
DROP POLICY IF EXISTS "Owners can update bookings for their rooms" ON public.booking;
DROP POLICY IF EXISTS "Owners can delete bookings for their rooms" ON public.booking;
DROP POLICY IF EXISTS "Admins can manage all bookings" ON public.booking;

CREATE POLICY "Authorized users can view bookings"
  ON public.booking
  FOR SELECT TO authenticated
  USING (
    user_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Authorized users can create bookings"
  ON public.booking
  FOR INSERT TO authenticated
  WITH CHECK (
    (
      user_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
      AND status = 'pending'::public.booking_status
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Authorized users can update bookings"
  ON public.booking
  FOR UPDATE TO authenticated
  USING (
    user_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  )
  WITH CHECK (
    (
      user_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
      AND status = 'cancelled'::public.booking_status
    )
    OR room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Authorized users can delete bookings"
  ON public.booking
  FOR DELETE TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

DROP POLICY IF EXISTS "Tenants can view their own payments" ON public.payment;
DROP POLICY IF EXISTS "Tenants can submit their own payment receipts" ON public.payment;
DROP POLICY IF EXISTS "Owners can view payments for their rooms" ON public.payment;
DROP POLICY IF EXISTS "Owners can create payments for their rooms" ON public.payment;
DROP POLICY IF EXISTS "Owners can update payments for their rooms" ON public.payment;
DROP POLICY IF EXISTS "Owners can delete payments for their rooms" ON public.payment;
DROP POLICY IF EXISTS "Admins can manage all payments" ON public.payment;

CREATE POLICY "Authorized users can view payments"
  ON public.payment
  FOR SELECT TO authenticated
  USING (
    user_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Authorized users can create payments"
  ON public.payment
  FOR INSERT TO authenticated
  WITH CHECK (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Authorized users can update payments"
  ON public.payment
  FOR UPDATE TO authenticated
  USING (
    user_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  )
  WITH CHECK (
    user_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Authorized users can delete payments"
  ON public.payment
  FOR DELETE TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

DROP POLICY IF EXISTS "Tenants can view their own complaints" ON public.complaint;
DROP POLICY IF EXISTS "Tenants can submit their own complaints" ON public.complaint;
DROP POLICY IF EXISTS "Tenants can update their own complaints" ON public.complaint;
DROP POLICY IF EXISTS "Tenants can delete their own complaints" ON public.complaint;
DROP POLICY IF EXISTS "Owners can view complaints for their rooms" ON public.complaint;
DROP POLICY IF EXISTS "Owners can update complaints for their rooms" ON public.complaint;
DROP POLICY IF EXISTS "Owners can delete complaints for their rooms" ON public.complaint;
DROP POLICY IF EXISTS "Admins can manage all complaints" ON public.complaint;

CREATE POLICY "Authorized users can view complaints"
  ON public.complaint
  FOR SELECT TO authenticated
  USING (
    user_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Authorized users can create complaints"
  ON public.complaint
  FOR INSERT TO authenticated
  WITH CHECK (
    (
      user_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
      AND status = 'pending'::public.complaint_status
      AND (
        attachment_url IS NULL
        OR attachment_url ~ (
          '^complaint_' ||
          (
            SELECT user_id::text
            FROM public.users
            WHERE auth_id = (SELECT auth.uid())
          ) ||
          '_[0-9]+[.](jpg|jpeg|png|webp)$'
        )
      )
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Authorized users can update complaints"
  ON public.complaint
  FOR UPDATE TO authenticated
  USING (
    user_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  )
  WITH CHECK (
    user_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );

CREATE POLICY "Authorized users can delete complaints"
  ON public.complaint
  FOR DELETE TO authenticated
  USING (
    user_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    OR room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id
        FROM public.users
        WHERE auth_id = (SELECT auth.uid())
      )
    )
    OR (SELECT public.is_admin())
  );
