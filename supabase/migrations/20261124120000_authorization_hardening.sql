CREATE OR REPLACE FUNCTION public.guard_profile_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.auth_id IS DISTINCT FROM OLD.auth_id THEN
    RAISE EXCEPTION 'Profile identifiers cannot be changed';
  END IF;

  IF auth.uid() IS NOT NULL
     AND OLD.auth_id = auth.uid()
     AND NOT public.is_admin()
     AND (
       NEW.email IS DISTINCT FROM OLD.email
       OR NEW.role IS DISTINCT FROM OLD.role
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
     ) THEN
    RAISE EXCEPTION 'Users cannot change protected profile fields';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER guard_profile_update
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_update();

CREATE OR REPLACE FUNCTION public.guard_booking_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  current_profile public.users%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  SELECT * INTO current_profile
  FROM public.users
  WHERE auth_id = auth.uid();

  IF current_profile.role = 'tenant'
     AND OLD.user_id = current_profile.user_id THEN
    IF (to_jsonb(NEW) - 'status') IS DISTINCT FROM
       (to_jsonb(OLD) - 'status')
       OR NEW.status <> 'cancelled'::public.booking_status THEN
      RAISE EXCEPTION 'Tenants may only cancel their own bookings';
    END IF;
    IF CURRENT_DATE - OLD.request_date < 30
       OR (
         (
           date_trunc('month', CURRENT_DATE) + INTERVAL '1 month - 1 day'
         )::date - CURRENT_DATE
       ) BETWEEN 7 AND 14 THEN
      RAISE EXCEPTION 'Booking cancellation is not allowed under current policy';
    END IF;
  ELSIF current_profile.role = 'owner'
        AND EXISTS (
          SELECT 1
          FROM public.room r
          JOIN public.house h ON h.house_id = r.house_id
          WHERE r.room_id = OLD.room_id
            AND h.owner_id = current_profile.user_id
        ) THEN
    IF (to_jsonb(NEW) - 'status') IS DISTINCT FROM
       (to_jsonb(OLD) - 'status')
       OR NEW.status NOT IN (
         'approved'::public.booking_status,
         'rejected'::public.booking_status,
         'cancelled'::public.booking_status
       ) THEN
      RAISE EXCEPTION 'Owners may only update booking status';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER guard_booking_update
  BEFORE UPDATE ON public.booking
  FOR EACH ROW EXECUTE FUNCTION public.guard_booking_update();

CREATE OR REPLACE FUNCTION public.guard_payment_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  current_profile public.users%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  SELECT * INTO current_profile
  FROM public.users
  WHERE auth_id = auth.uid();

  IF current_profile.role = 'tenant'
     AND OLD.user_id = current_profile.user_id THEN
    IF (to_jsonb(NEW) - 'receipt_url') IS DISTINCT FROM
       (to_jsonb(OLD) - 'receipt_url') THEN
      RAISE EXCEPTION 'Tenants may only update their payment receipt';
    END IF;
    IF NEW.receipt_url IS DISTINCT FROM OLD.receipt_url THEN
      IF OLD.status::text <> 'pending' THEN
        RAISE EXCEPTION 'Only pending payments may receive a receipt';
      END IF;
      IF NEW.receipt_url IS NOT NULL
         AND NEW.receipt_url !~ (
           '^payment_' || OLD.payment_id::text ||
           '_[0-9]+[.](jpg|jpeg|png|webp)$'
         ) THEN
        RAISE EXCEPTION 'Payment receipts must use private storage paths';
      END IF;
    END IF;
  ELSIF current_profile.role = 'owner'
        AND EXISTS (
          SELECT 1
          FROM public.room r
          JOIN public.house h ON h.house_id = r.house_id
          WHERE r.room_id = OLD.room_id
            AND h.owner_id = current_profile.user_id
        ) THEN
    IF (to_jsonb(NEW) - ARRAY['status', 'paid_date']) IS DISTINCT FROM
       (to_jsonb(OLD) - ARRAY['status', 'paid_date']) THEN
      RAISE EXCEPTION 'Owners may only update payment status and paid date';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER guard_payment_update
  BEFORE UPDATE ON public.payment
  FOR EACH ROW EXECUTE FUNCTION public.guard_payment_update();

CREATE OR REPLACE FUNCTION public.guard_complaint_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  current_profile public.users%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  SELECT * INTO current_profile
  FROM public.users
  WHERE auth_id = auth.uid();

  IF current_profile.role = 'tenant'
     AND OLD.user_id = current_profile.user_id THEN
    IF (to_jsonb(NEW) - ARRAY[
      'title', 'description', 'category', 'priority', 'attachment_url'
    ]) IS DISTINCT FROM
       (to_jsonb(OLD) - ARRAY[
         'title', 'description', 'category', 'priority', 'attachment_url'
       ]) THEN
      RAISE EXCEPTION 'Tenants cannot change complaint status or response';
    END IF;
    IF NEW.attachment_url IS DISTINCT FROM OLD.attachment_url
       AND NEW.attachment_url IS NOT NULL
       AND NEW.attachment_url !~ (
         '^complaint_' || OLD.user_id::text ||
         '_[0-9]+[.](jpg|jpeg|png|webp)$'
       ) THEN
      RAISE EXCEPTION 'Complaint attachments must use private storage paths';
    END IF;
  ELSIF current_profile.role = 'owner'
        AND EXISTS (
          SELECT 1
          FROM public.room r
          JOIN public.house h ON h.house_id = r.house_id
          WHERE r.room_id = OLD.room_id
            AND h.owner_id = current_profile.user_id
        ) THEN
    IF (to_jsonb(NEW) - ARRAY['status', 'response']) IS DISTINCT FROM
       (to_jsonb(OLD) - ARRAY['status', 'response']) THEN
      RAISE EXCEPTION 'Owners may only update complaint status and response';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER guard_complaint_update
  BEFORE UPDATE ON public.complaint
  FOR EACH ROW EXECUTE FUNCTION public.guard_complaint_update();

UPDATE public.payment
SET receipt_url = regexp_replace(
  receipt_url,
  '^https?://[^/]+/storage/v1/object/public/payment-receipts/',
  ''
)
WHERE receipt_url ~
  '^https?://[^/]+/storage/v1/object/public/payment-receipts/';

UPDATE public.complaint
SET attachment_url = regexp_replace(
  attachment_url,
  '^https?://[^/]+/storage/v1/object/public/complaint-attachments/',
  ''
)
WHERE attachment_url ~
  '^https?://[^/]+/storage/v1/object/public/complaint-attachments/';

UPDATE storage.buckets
SET public = false
WHERE id IN ('payment-receipts', 'complaint-attachments');

DROP POLICY IF EXISTS "Tenants can view and create their own bookings"
  ON public.booking;
DROP POLICY IF EXISTS "Owners and admins can view and manage bookings for their rooms"
  ON public.booking;

CREATE POLICY "Tenants can view their own bookings" ON public.booking
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
  );

CREATE POLICY "Tenants can create pending bookings" ON public.booking
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    AND status = 'pending'::public.booking_status
  );

CREATE POLICY "Tenants can cancel their own bookings" ON public.booking
  FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
  )
  WITH CHECK (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    AND status = 'cancelled'::public.booking_status
  );

CREATE POLICY "Owners can view bookings for their rooms" ON public.booking
  FOR SELECT TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Owners can update bookings for their rooms" ON public.booking
  FOR UPDATE TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Owners can delete bookings for their rooms" ON public.booking
  FOR DELETE TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Admins can manage all bookings" ON public.booking
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Tenants can view and update proof on their payments"
  ON public.payment;
DROP POLICY IF EXISTS "Owners and admins can manage payments for their rooms"
  ON public.payment;

CREATE POLICY "Tenants can view their own payments" ON public.payment
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
  );

CREATE POLICY "Tenants can submit their own payment receipts" ON public.payment
  FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
  )
  WITH CHECK (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
  );

CREATE POLICY "Owners can view payments for their rooms" ON public.payment
  FOR SELECT TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Owners can create payments for their rooms" ON public.payment
  FOR INSERT TO authenticated
  WITH CHECK (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Owners can update payments for their rooms" ON public.payment
  FOR UPDATE TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Owners can delete payments for their rooms" ON public.payment
  FOR DELETE TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Admins can manage all payments" ON public.payment
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Tenants can manage their complaints"
  ON public.complaint;
DROP POLICY IF EXISTS "Owners and admins can view and respond to complaints for their rooms"
  ON public.complaint;

CREATE POLICY "Tenants can view their own complaints" ON public.complaint
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
  );

CREATE POLICY "Tenants can submit their own complaints" ON public.complaint
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
    AND status = 'pending'::public.complaint_status
    AND (
      attachment_url IS NULL
      OR attachment_url ~ (
        '^complaint_' ||
        (SELECT user_id::text FROM public.users WHERE auth_id = auth.uid()) ||
        '_[0-9]+[.](jpg|jpeg|png|webp)$'
      )
    )
  );

CREATE POLICY "Tenants can update their own complaints" ON public.complaint
  FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
  )
  WITH CHECK (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
  );

CREATE POLICY "Tenants can delete their own complaints" ON public.complaint
  FOR DELETE TO authenticated
  USING (
    user_id = (SELECT user_id FROM public.users WHERE auth_id = auth.uid())
  );

CREATE POLICY "Owners can view complaints for their rooms" ON public.complaint
  FOR SELECT TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Owners can update complaints for their rooms" ON public.complaint
  FOR UPDATE TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Owners can delete complaints for their rooms" ON public.complaint
  FOR DELETE TO authenticated
  USING (
    room_id IN (
      SELECT r.room_id
      FROM public.room r
      JOIN public.house h ON h.house_id = r.house_id
      WHERE h.owner_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
    )
  );

CREATE POLICY "Admins can manage all complaints" ON public.complaint
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Authenticated users can upload payment receipts"
  ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload complaint attachments"
  ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete complaint attachments"
  ON storage.objects;

CREATE POLICY "Tenants can upload their own payment receipts"
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'payment-receipts'
    AND EXISTS (
      SELECT 1
      FROM public.payment p
      WHERE p.user_id = (
        SELECT user_id FROM public.users WHERE auth_id = auth.uid()
      )
        AND p.status::text = 'pending'
        AND name ~ (
          '^payment_' || p.payment_id::text ||
          '_[0-9]+[.](jpg|jpeg|png|webp)$'
        )
    )
  );

CREATE POLICY "Authorized users can view attached payment receipts"
  ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'payment-receipts'
    AND EXISTS (
      SELECT 1
      FROM public.payment p
      WHERE p.receipt_url = name
        AND (
          p.user_id = (
            SELECT user_id FROM public.users WHERE auth_id = auth.uid()
          )
          OR p.room_id IN (
            SELECT r.room_id
            FROM public.room r
            JOIN public.house h ON h.house_id = r.house_id
            WHERE h.owner_id = (
              SELECT user_id FROM public.users WHERE auth_id = auth.uid()
            )
          )
          OR public.is_admin()
        )
    )
  );

CREATE POLICY "Users can upload their own complaint attachments"
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'complaint-attachments'
    AND name ~ (
      '^complaint_' ||
      (
        SELECT user_id::text
        FROM public.users
        WHERE auth_id = auth.uid()
      ) ||
      '_[0-9]+[.](jpg|jpeg|png|webp)$'
    )
  );

CREATE POLICY "Authorized users can view attached complaint files"
  ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'complaint-attachments'
    AND EXISTS (
      SELECT 1
      FROM public.complaint c
      WHERE c.attachment_url = name
        AND (
          c.user_id = (
            SELECT user_id FROM public.users WHERE auth_id = auth.uid()
          )
          OR c.room_id IN (
            SELECT r.room_id
            FROM public.room r
            JOIN public.house h ON h.house_id = r.house_id
            WHERE h.owner_id = (
              SELECT user_id FROM public.users WHERE auth_id = auth.uid()
            )
          )
          OR public.is_admin()
        )
    )
  );

CREATE POLICY "Authorized users can delete attached complaint files"
  ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'complaint-attachments'
    AND EXISTS (
      SELECT 1
      FROM public.complaint c
      WHERE c.attachment_url = name
        AND (
          c.user_id = (
            SELECT user_id FROM public.users WHERE auth_id = auth.uid()
          )
          OR c.room_id IN (
            SELECT r.room_id
            FROM public.room r
            JOIN public.house h ON h.house_id = r.house_id
            WHERE h.owner_id = (
              SELECT user_id FROM public.users WHERE auth_id = auth.uid()
            )
          )
          OR public.is_admin()
        )
    )
  );

REVOKE ALL ON FUNCTION public.guard_profile_update()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.guard_booking_update()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.guard_payment_update()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.guard_complaint_update()
  FROM PUBLIC, anon, authenticated;
