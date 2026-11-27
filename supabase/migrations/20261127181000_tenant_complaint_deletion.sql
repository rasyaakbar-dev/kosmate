DROP POLICY IF EXISTS "Tenants can delete their own complaints"
  ON public.complaint;
DROP POLICY IF EXISTS "Authorized users can delete complaints"
  ON public.complaint;

CREATE POLICY "Tenants can delete unprocessed complaints"
  ON public.complaint
  FOR DELETE TO authenticated
  USING (
    user_id = (
      SELECT user_id
      FROM public.users
      WHERE auth_id = (SELECT auth.uid())
    )
    AND status IN (
      'pending'::public.complaint_status,
      'rejected'::public.complaint_status
    )
  );

DROP POLICY IF EXISTS "Authorized users can delete attached complaint files"
  ON storage.objects;

CREATE POLICY "Authorized users can delete attached complaint files"
  ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'complaint-attachments'
    AND (
      name ~ (
        '^complaint_' ||
        (
          SELECT user_id::text
          FROM public.users
          WHERE auth_id = (SELECT auth.uid())
        ) ||
        '_[0-9]+[.](jpg|jpeg|png|webp)$'
      )
      OR EXISTS (
        SELECT 1
        FROM public.complaint c
        WHERE c.attachment_url = name
          AND (
            c.user_id = (
              SELECT user_id
              FROM public.users
              WHERE auth_id = (SELECT auth.uid())
            )
            OR c.room_id IN (
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
      )
    )
  );
