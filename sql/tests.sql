-- Boundary fixture runs in the transaction and is rolled back to the savepoint.
SAVEPOINT boundary_fixture;
INSERT INTO order_lines VALUES
  (-1, 'SKU01', 'Direct', '2025-12-01', 100, '2025-12-31', 'Fit'),
  (-2, 'SKU01', 'Direct', '2025-12-02', 100, NULL, NULL),
  (-3, 'SKU01', 'Direct', '2025-11-30', 100, '2025-12-31', 'Fit'),
  (-4, 'SKU01', 'Direct', '2025-11-30', 100, NULL, NULL);
DO $$
BEGIN
  IF (SELECT array_agg(line_id ORDER BY line_id) FROM mature_lines
      WHERE line_id < 0) IS DISTINCT FROM ARRAY[-4,-3,-1] THEN
    RAISE EXCEPTION 'Cohort maturity boundary failed';
  END IF;
  IF (SELECT array_agg(returned_30d ORDER BY line_id) FROM mature_lines
      WHERE line_id < 0) IS DISTINCT FROM ARRAY[false,false,true] THEN
    RAISE EXCEPTION '30-day return boundary failed';
  END IF;
END $$;
ROLLBACK TO SAVEPOINT boundary_fixture;
DO $$
BEGIN
  IF (SELECT sum(delivered) FROM monthly_cohorts) IS DISTINCT FROM
      (SELECT count(*)::numeric FROM mature_lines) THEN
    RAISE EXCEPTION 'Cohort totals do not reconcile';
  END IF;
  IF EXISTS (SELECT 1 FROM segment_priority WHERE returned > delivered OR delivered < 100) THEN
    RAISE EXCEPTION 'Segment denominator failed';
  END IF;
END $$;
