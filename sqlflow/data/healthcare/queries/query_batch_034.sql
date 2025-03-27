-- Query 1
WITH MonthlyVisitCounts AS (
    SELECT
        patient_id,
        COUNT(visit_id) AS monthly_visits,
        DATE_TRUNC('month', visit_date) AS visit_month
    FROM visits
    GROUP BY patient_id, visit_month
)
SELECT
    p.first_name,
    p.last_name,
    COUNT(DISTINCT d.diagnosis_id) AS num_diagnoses,
    MAX(pv.monthly_visits) AS max_monthly_visits,
    COALESCE(SUM(clm.paid_amount), 0) AS total_paid,
    COALESCE(SUM(clm.billed_amount), 0) - COALESCE(SUM(clm.paid_amount), 0) AS amount_outstanding
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN diagnoses d ON v.visit_id = d.visit_id
LEFT JOIN claims clm ON v.visit_id = clm.visit_id
JOIN (SELECT patient_id, MAX(monthly_visits) AS monthly_visits FROM MonthlyVisitCounts GROUP BY patient_id) pv
  ON p.patient_id = pv.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name
HAVING COUNT(DISTINCT d.diagnosis_id) > 5;

-- Query 2
WITH RecentVitalSigns AS (
    SELECT
        visit_id,
        MAX(recorded_at) AS recent_vital_recorded
    FROM vitals
    GROUP BY visit_id
)
SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    AVG(vv.bmi) OVER (PARTITION BY v.patient_id) AS avg_bmi,
    MAX(vv.blood_pressure_systolic) FILTER (WHERE vv.was_emergency) AS max_systolic_emergency,
    cnt.condition_count
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN vitals vv ON v.visit_id = vv.visit_id
LEFT JOIN (
    SELECT patient_id, COUNT(condition_id) AS condition_count
    FROM conditions
    WHERE condition_status = 'active'
    GROUP BY patient_id
) cnt ON p.patient_id = cnt.patient_id
WHERE vv.recorded_at = (SELECT recent_vital_recorded FROM RecentVitalSigns rv WHERE rv.visit_id = vv.visit_id);

-- Query 3
WITH LanguageCounts AS (
    SELECT
        p.language_id,
        COUNT(p.patient_id) AS num_patients
    FROM patients p
    GROUP BY p.language_id
)
SELECT
   ln.language_name,
   c.encounter_type_name,
   AVG(pr.amount) AS avg_amount,
   MAX(pr.amount) - MIN(pr.amount) AS amount_range
FROM encounters et
JOIN visits v ON et.encounter_type_id = v.encounter_type_id
JOIN medications m ON v.visit_id = m.visit_id
JOIN billing b ON v.visit_id = b.visit_id
JOIN procedures pr ON v.visit_id = pr.visit_id
JOIN patients p ON v.patient_id = p.patient_id
JOIN languages ln ON p.language_id = ln.language_id
JOIN LanguageCounts lc ON p.language_id = lc.language_id
GROUP BY ln.language_id, c.encounter_type_id
HAVING COUNT(m.medication_id) > 10 AND MAX(pr.amount) > 0;

-- Query 4
WITH TotalMedications AS (
    SELECT
        visit_id,
        COUNT(medication_id) AS total_medications
    FROM medications
    GROUP BY visit_id
)
SELECT
    rh.race_ethnicity_name,
    AVG(ls.result_value) AS avg_lab_result,
    CASE
        WHEN AVG(ls.result_value) > 5 THEN 'high'
        ELSE 'normal'
    END AS lab_result_status,
    SUM(em.amount) AS employment_income
FROM patients pa
JOIN race_ethnicity rh ON pa.race_ethnicity_id = rh.race_ethnicity_id
JOIN visits vi ON pa.patient_id = vi.patient_id
JOIN labs ls ON vi.visit_id = ls.visit_id
JOIN TotalMedications tm ON vi.visit_id = tm.visit_id
LEFT JOIN employment_status em ON pa.patient_id = em.patient_id
GROUP BY rh.race_ethnicity_name
HAVING AVG(ls.result_value) IS NOT NULL;

-- Query 5
WITH DischargeSummary AS (
    SELECT
        visit_id,
        discharge_time - admission_time AS stay_duration
    FROM visits
)
SELECT
    prov.specialty,
    COUNT(DISTINCT d.diagnosis_id) AS diagnosis_count,
    COUNT(v.visit_id) FILTER (WHERE v.was_emergency) AS emergency_visits,
    AVG(ds.stay_duration) AS avg_stay_duration
FROM providers prov
JOIN visits v ON prov.provider_id = v.provider_id
JOIN diagnoses d ON v.visit_id = d.visit_id
JOIN DischargeSummary ds ON v.visit_id = ds.visit_id
GROUP BY prov.provider_id
HAVING AVG(ds.stay_duration) > INTERVAL '2 days';

-- Query 6
WITH SDOHCount AS (
    SELECT
        patient_id,
        COUNT(sdoh_id) AS sdoh_entries
    FROM sdoh_entries
    WHERE recorded_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY patient_id
)
SELECT
    p.first_name,
    p.last_name,
    sd.sdoh_entries,
    hs.housing_type,
    ROUND(SUM(cl.claim_amount) / NULLIF(COUNT(cl.claim_id), 0), 2) AS avg_claim_amount
FROM patients p
JOIN SDOHCount sd ON p.patient_id = sd.patient_id
LEFT JOIN housing_status hs ON p.patient_id = hs.patient_id
JOIN claims cl ON p.patient_id = cl.patient_id
WHERE cl.claim_status IN ('paid', 'pending')
GROUP BY p.patient_id, sd.sdoh_entries, hs.housing_type;

-- Query 7
WITH RiskScores AS (
    SELECT
        patient_id,
        AVG(score_value) AS avg_risk_score
    FROM risk_scores
    GROUP BY patient_id
)
SELECT
    pat.first_name,
    pat.last_name,
    rs.avg_risk_score,
    MIN(sv.survey_score) as min_survey_score,
    NULLIF(MAX(ptc.assigned_date), CURRENT_DATE) AS latest_care_team_assignment
FROM patients pat
LEFT JOIN RiskScores rs ON pat.patient_id = rs.patient_id
LEFT JOIN surveys sv ON pat.patient_id = sv.patient_id
LEFT JOIN patient_care_team ptc ON pat.patient_id = ptc.patient_id
WHERE sv.survey_date > CURRENT_DATE - INTERVAL '6 months'
GROUP BY pat.patient_id, rs.avg_risk_score
HAVING rs.avg_risk_score IS NOT NULL;

-- Query 8
WITH RecentPayments AS (
    SELECT
        claim_id,
        MAX(payment_date) AS last_payment_date
    FROM payments
    GROUP BY claim_id
)
SELECT
    prov.first_name AS provider_first_name,
    prov.last_name AS provider_last_name,
    SUM(pm.amount) AS total_payment,
    AVG(b.amount) AS avg_billed_amount,
    ip.last_payment_date
FROM providers prov
JOIN visits v ON prov.provider_id = v.provider_id
JOIN billing b ON v.visit_id = b.visit_id
JOIN claims cl ON v.visit_id = cl.visit_id
JOIN payments pm ON cl.claim_id = pm.claim_id
JOIN RecentPayments ip ON cl.claim_id = ip.claim_id
GROUP BY prov.provider_id, ip.last_payment_date
HAVING SUM(pm.amount) > 1000;

-- Query 9
WITH ActiveAllergies AS (
    SELECT
        patient_id,
        COUNT(allergy_id) AS allergy_count
    FROM allergies
    WHERE severity = 'high'
    GROUP BY patient_id
)
SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    AVG(ba.billed_amount) AS avg_billed,
    aa.allergy_count,
    CASE
        WHEN AVG(ba.billed_amount) > 1000 THEN 'high'
        ELSE 'low'
    END AS billing_category
FROM patients p
LEFT JOIN ActiveAllergies aa ON p.patient_id = aa.patient_id
JOIN claims ca ON p.patient_id = ca.patient_id
JOIN billing ba ON ca.claim_id = ba.claim_id
GROUP BY p.patient_id, aa.allergy_count
HAVING COUNT(ca.claim_id) > 5;

-- Query 10
WITH SurveyDetails AS (
    SELECT
        patient_id,
        survey_type,
        AVG(survey_score) AS avg_score
    FROM surveys
    GROUP BY patient_id, survey_type
)
SELECT
    p.first_name,
    p.last_name,
    ed.employment_type,
    sd.survey_type,
    sd.avg_score,
    CASE
        WHEN AVG(cl.paid_amount) > 500 THEN 'high payer'
        ELSE 'low payer'
    END AS payer_category
FROM patients p
JOIN SurveyDetails sd ON p.patient_id = sd.patient_id
LEFT JOIN employment_status ed ON p.patient_id = ed.patient_id
LEFT JOIN claims cl ON p.patient_id = cl.patient_id
GROUP BY p.patient_id, ed.employment_type, sd.survey_type, sd.avg_score
HAVING sd.avg_score > 50;