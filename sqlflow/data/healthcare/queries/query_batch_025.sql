-- 1
WITH PatientVisitCounts AS (
    SELECT p.patient_id, COUNT(v.visit_id) AS total_visits
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
    WHERE v.visit_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY p.patient_id
),
ProviderVisitDetails AS (
    SELECT pr.provider_id, pr.specialty, COUNT(v.visit_id) AS visits_count
    FROM providers pr
    JOIN visits v ON pr.provider_id = v.provider_id
    GROUP BY pr.provider_id, pr.specialty
)
SELECT p.first_name, p.last_name, pv.total_visits, pr.specialty, pvd.visits_count
FROM PatientVisitCounts pv
JOIN patients p ON p.patient_id = pv.patient_id
JOIN (
    SELECT pr.provider_id, pr.specialty, AVG(pv.total_visits) OVER (PARTITION BY pr.specialty) AS avg_specialty_visits
    FROM providers pr
    JOIN ProviderVisitDetails pvd ON pr.provider_id = pvd.provider_id
    JOIN visits v ON pr.provider_id = v.provider_id
    JOIN PatientVisitCounts pv ON v.patient_id = pv.patient_id
) AS pr ON pv.total_visits > pr.avg_specialty_visits
WHERE pr.provider_id IN (
    SELECT provider_id FROM providers WHERE specialty = 'Cardiology'
);

-- 2
WITH HighRiskPatients AS (
    SELECT rs.patient_id, rs.score_value
    FROM risk_scores rs
    WHERE rs.score_value > 7
)
SELECT DISTINCT pr.first_name, pr.last_name, rs.score_value, COUNT(clm.claim_id) AS claims_count,
       AVG(CASE WHEN v.was_emergency THEN 1 ELSE 0 END) AS emergency_visit_ratio
FROM HighRiskPatients rs
JOIN patients pr ON rs.patient_id = pr.patient_id
JOIN claims clm ON pr.patient_id = clm.patient_id
LEFT JOIN visits v ON clm.visit_id = v.visit_id
GROUP BY pr.patient_id, rs.score_value
HAVING COUNT(clm.claim_id) > 0;

-- 3
WITH RecentDiagnoses AS (
    SELECT v.visit_id, v.visit_date, d.diagnosis_code
    FROM visits v
    JOIN diagnoses d ON v.visit_id = d.visit_id
    WHERE d.diagnosis_date > CURRENT_DATE - INTERVAL '6 months'
)
SELECT p.first_name, p.last_name, v.was_emergency, d.diagnosis_code,
       ROW_NUMBER() OVER (PARTITION BY p.patient_id ORDER BY v.visit_date DESC) AS rn
FROM patients p
JOIN (
    SELECT vd.visit_id, vd.visit_date, vd.diagnosis_code, vd.was_emergency
    FROM RecentDiagnoses vd
    JOIN visits v ON vd.visit_id = v.visit_id
) d ON p.patient_id = (
    SELECT patient_id
    FROM visits v
    WHERE v.visit_id = d.visit_id
)
WHERE d.visit_date = (
    SELECT MAX(rv.visit_date)
    FROM RecentDiagnoses rv
    WHERE rv.visit_id = d.visit_id
);

-- 4
WITH VitalStats AS (
    SELECT v.visit_id, vit.patient_id,
           AVG(vit.bmi) AS avg_bmi,
           MAX(CASE WHEN vit.heart_rate > 100 THEN 1 ELSE 0 END) AS high_heart_rate_flag
    FROM visits v
    JOIN vitals vit ON v.visit_id = vit.visit_id
    GROUP BY v.visit_id, vit.patient_id
)
SELECT pr.first_name, pr.last_name, vt.avg_bmi, prd.npi_number,
       COUNT(med.medication_id) AS meds_prescribed
FROM VitalStats vt
JOIN patients pr ON vt.patient_id = pr.patient_id
JOIN visits v ON vt.visit_id = v.visit_id
JOIN medications med ON v.visit_id = med.visit_id
JOIN providers prd ON v.provider_id = prd.provider_id
GROUP BY pr.first_name, pr.last_name, vt.avg_bmi, prd.npi_number;

-- 5
WITH AllergyCounts AS (
    SELECT patient_id, COUNT(allergy_id) AS allergy_count
    FROM allergies
    GROUP BY patient_id
)
SELECT p.first_name, p.last_name, a.allergy_count,
       SUM(b.amount) AS total_billed,
       COUNT(DISTINCT CASE WHEN s.severity = 'Severe' THEN s.symptom_id END) AS severe_symptom_count
FROM patients p
JOIN AllergyCounts a ON p.patient_id = a.patient_id
JOIN claims c ON p.patient_id = c.patient_id
JOIN billing b ON c.claim_id = b.claim_id
LEFT JOIN symptoms s ON c.visit_id = s.visit_id
GROUP BY p.first_name, p.last_name, a.allergy_count;

-- 6
WITH ImagingStats AS (
    SELECT visit_id, imaging_type, COUNT(imaging_id) AS imaging_count
    FROM imaging
    GROUP BY visit_id, imaging_type
)
SELECT p.first_name, p.last_name, i.imaging_type, i.imaging_count,
       AVG(l.result_value) FILTER (WHERE l.result_flag = 'high') AS avg_high_lab_value
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN ImagingStats i ON v.visit_id = i.visit_id
LEFT JOIN labs l ON v.visit_id = l.visit_id
GROUP BY p.first_name, p.last_name, i.imaging_type, i.imaging_count;

-- 7
WITH SurveyScores AS (
    SELECT patient_id, AVG(survey_score) AS avg_survey_score
    FROM surveys
    WHERE survey_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY patient_id
)
SELECT pr.first_name || ' ' || pr.last_name AS full_name, ss.avg_survey_score, ct.team_name
FROM SurveyScores ss
JOIN patients pr ON ss.patient_id = pr.patient_id
JOIN patient_care_team pct ON pr.patient_id = pct.patient_id
JOIN care_teams ct ON pct.care_team_id = ct.care_team_id
WHERE ss.avg_survey_score IN (
    SELECT MAX(avg_survey_score) FROM SurveyScores
);

-- 8
WITH EmploymentData AS (
    SELECT patient_id, employment_type, COUNT(employment_id) AS employment_records
    FROM employment_status
    GROUP BY patient_id, employment_type
)
SELECT pr.first_name, pr.last_name, e.employment_type, e.employment_records,
       COUNT(DISTINCT hv.housing_id) AS housing_types_count
FROM patients pr
LEFT JOIN EmploymentData e ON pr.patient_id = e.patient_id
LEFT JOIN housing_status hv ON pr.patient_id = hv.patient_id
GROUP BY pr.first_name, pr.last_name, e.employment_type, e.employment_records;

-- 9
WITH PatientIncome AS (
    SELECT patient_id, income_level
    FROM income_brackets
    WHERE recorded_date = (
        SELECT MAX(recorded_date) FROM income_brackets
    )
)
SELECT DISTINCT p.patient_id, p.first_name, p.last_name, pi.income_level,
       SUM(pmt.amount) AS total_payments_received,
       COUNT(DISTINCT s.screening_id) FILTER (WHERE s.result = 'Positive') AS positive_screenings
FROM patients p
JOIN PatientIncome pi ON p.patient_id = pi.patient_id
JOIN payments pmt ON p.patient_id = (
    SELECT patient_id FROM claims WHERE claim_id = pmt.claim_id
)
LEFT JOIN screenings s ON p.patient_id = s.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, pi.income_level;

-- 10
WITH ProcedureStats AS (
    SELECT visit_id, COUNT(procedure_id) AS procedure_count
    FROM procedures
    GROUP BY visit_id
)
SELECT p.first_name, p.last_name, ps.procedure_count,
       CASE 
           WHEN SUM(vt.height_cm) > 1000 THEN 'Tall'
           ELSE 'Short' 
       END AS height_category,
       COUNT(DISTINCT r.risk_score_id) FILTER (WHERE r.score_value > 9) AS high_risk_counts
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN ProcedureStats ps ON v.visit_id = ps.visit_id
LEFT JOIN vitals vt ON v.visit_id = vt.visit_id
LEFT JOIN risk_scores r ON p.patient_id = r.patient_id
GROUP BY p.first_name, p.last_name, ps.procedure_count;
