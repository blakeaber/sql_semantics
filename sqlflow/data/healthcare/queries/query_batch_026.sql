WITH RecentVisits AS (
    SELECT patient_id, MAX(visit_date) AS last_visit_date
    FROM visits
    GROUP BY patient_id
),
HighRiskPatients AS (
    SELECT patient_id, AVG(score_value) AS avg_risk_score
    FROM risk_scores
    WHERE calculated_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY patient_id
    HAVING AVG(score_value) > 85
)
SELECT p.patient_id, p.first_name, p.last_name, 
       COALESCE(l.language_name, 'Unknown') AS language,
       (v.discharge_time - v.admission_time) AS length_of_stay,
       (CASE 
            WHEN so.survey_score >= 90 THEN 'High Satisfaction'
            WHEN so.survey_score >= 70 THEN 'Moderate Satisfaction'
            ELSE 'Low Satisfaction'
        END) AS satisfaction_level
FROM patients p
JOIN HighRiskPatients hr ON p.patient_id = hr.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN languages l ON p.language_id = l.language_id
LEFT JOIN (SELECT patient_id, MAX(survey_date) AS latest_survey_date
           FROM surveys
           GROUP BY patient_id) r ON p.patient_id = r.patient_id
LEFT JOIN surveys so ON r.patient_id = so.patient_id AND r.latest_survey_date = so.survey_date
WHERE p.patient_id IN (SELECT rv.patient_id FROM RecentVisits rv)
AND v.was_emergency = TRUE
ORDER BY satisfaction_level DESC, length_of_stay ASC;

WITH EmergencyVisits AS (
    SELECT visit_id, patient_id
    FROM visits
    WHERE was_emergency = TRUE
),
PatientConditions AS (
    SELECT patient_id, condition_name, 
           (CASE 
               WHEN COUNT(condition_id) > 5 THEN 'Chronic'
               ELSE 'Acute'
           END) AS condition_severity
    FROM conditions
    GROUP BY patient_id, condition_name
)
SELECT ev.patient_id, p.first_name, p.last_name,
       COALESCE(ic.insurance_id, 'Unknown') AS active_insurance,
       AVG(c.claim_amount) AS avg_claim_amount,
       COUNT(pr.procedure_id) AS procedure_count
FROM EmergencyVisits ev
JOIN patients p ON ev.patient_id = p.patient_id
LEFT JOIN conditions c ON ev.patient_id = c.patient_id
LEFT JOIN insurance ic ON p.insurance_id = ic.insurance_id
LEFT JOIN PatientConditions pc ON ev.patient_id = pc.patient_id
LEFT JOIN procedures pr ON ev.visit_id = pr.visit_id
WHERE p.created_at > CURRENT_DATE - INTERVAL '5 years'
GROUP BY ev.patient_id, p.first_name, p.last_name, active_insurance
HAVING AVG(c.claim_amount) > 1000
ORDER BY procedure_count DESC;

WITH LongStayVisits AS (
    SELECT visit_id, patient_id, discharge_time - admission_time AS stay_duration
    FROM visits
    WHERE (discharge_time - admission_time) > INTERVAL '48 hours'
),
RecentMedications AS (
    SELECT visit_id, medication_name
    FROM medications
    WHERE start_date > CURRENT_DATE - INTERVAL '6 months'
)
SELECT lv.patient_id, p.first_name, p.last_name,
       COUNT(di.diagnosis_id) AS diagnosis_count,
       STRING_AGG(m.medication_name, ', ') AS recent_medications
FROM LongStayVisits lv
JOIN patients p ON lv.patient_id = p.patient_id
LEFT JOIN diagnoses di ON lv.visit_id = di.visit_id
LEFT JOIN RecentMedications rm ON lv.visit_id = rm.visit_id
LEFT JOIN medications m ON rm.visit_id = m.visit_id
GROUP BY lv.patient_id, p.first_name, p.last_name
HAVING COUNT(di.diagnosis_id) > 3
ORDER BY diagnosis_count DESC;

WITH VisitDiagnoses AS (
    SELECT visit_id, COUNT(diagnosis_id) AS total_diagnoses
    FROM diagnoses
    GROUP BY visit_id
),
ProviderSpecialties AS (
    SELECT provider_id, specialty
    FROM providers
    WHERE specialty IN ('Cardiology', 'Neurology')
)
SELECT p.patient_id, p.first_name, p.last_name,
       v.visit_date, et.encounter_type_name, d.total_diagnoses
FROM visits v
JOIN VisitDiagnoses d ON v.visit_id = d.visit_id
JOIN patients p ON v.patient_id = p.patient_id
JOIN encounter_types et ON v.encounter_type_id = et.encounter_type_id
JOIN ProviderSpecialties ps ON v.provider_id = ps.provider_id
WHERE d.total_diagnoses > 2
ORDER BY v.visit_date DESC, total_diagnoses DESC;

WITH MedicationUsage AS (
    SELECT patient_id, COUNT(DISTINCT medication_id) AS unique_medications
    FROM medications
    WHERE start_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY patient_id
),
RecentAllergies AS (
    SELECT patient_id, COUNT(allergy_id) AS total_allergies
    FROM allergies
    WHERE recorded_date > CURRENT_DATE - INTERVAL '2 years'
    GROUP BY patient_id
)
SELECT p.patient_id, p.first_name, p.last_name,
       mu.unique_medications, ra.total_allergies,
       AVG(b.billed_amount) AS avg_billed_amount
FROM patients p
LEFT JOIN MedicationUsage mu ON p.patient_id = mu.patient_id
LEFT JOIN RecentAllergies ra ON p.patient_id = ra.patient_id
LEFT JOIN claims c ON p.patient_id = c.patient_id
LEFT JOIN billing b ON c.claim_id = b.claim_id
GROUP BY p.patient_id, p.first_name, p.last_name, mu.unique_medications, ra.total_allergies
HAVING mu.unique_medications > 5 OR ra.total_allergies > 2
ORDER BY avg_billed_amount DESC;

WITH PastScreenings AS (
    SELECT patient_id, COUNT(screening_id) AS screening_count
    FROM screenings
    WHERE screening_date > CURRENT_DATE - INTERVAL '3 years'
    GROUP BY patient_id
),
HeartConditions AS (
    SELECT condition_id, patient_id, condition_name
    FROM conditions
    WHERE condition_name LIKE '%Heart%'
)
SELECT ps.patient_id, p.first_name, p.last_name,
       ps.screening_count, hc.condition_name
FROM PastScreenings ps
JOIN patients p ON ps.patient_id = p.patient_id
LEFT JOIN HeartConditions hc ON ps.patient_id = hc.patient_id
LEFT JOIN visits v ON ps.patient_id = v.patient_id
WHERE ps.screening_count > 1
ORDER BY ps.screening_count DESC;

WITH CriticalLabResults AS (
    SELECT visit_id, test_name, 
           (CASE 
               WHEN result_value > 5.0 THEN 'Critical'
               ELSE 'Normal'
           END) AS criticality
    FROM labs
    WHERE result_flag = 'H'
),
CurrentConditions AS (
    SELECT patient_id, condition_name
    FROM conditions
    WHERE condition_status = 'Active'
)
SELECT v.visit_id, p.first_name, p.last_name,
       cr.test_name, cr.criticality, cc.condition_name
FROM visits v
JOIN patients p ON v.patient_id = p.patient_id
LEFT JOIN CriticalLabResults cr ON v.visit_id = cr.visit_id
LEFT JOIN CurrentConditions cc ON p.patient_id = cc.patient_id
WHERE cr.criticality = 'Critical'
ORDER BY cr.test_name;

WITH IncomeDetails AS (
    SELECT patient_id, 
           (CASE 
               WHEN income_level = 'Low' THEN 'L'
               WHEN income_level = 'Medium' THEN 'M'
               ELSE 'H'
           END) AS income_bracket
    FROM income_brackets
    WHERE recorded_date > CURRENT_DATE - INTERVAL '1 year'
),
VitalStats AS (
    SELECT visit_id, patient_id, bmi
    FROM vitals
    WHERE recorded_at > CURRENT_DATE - INTERVAL '1 year' AND bmi > 25
)
SELECT i.patient_id, p.first_name, p.last_name,
       i.income_bracket, vs.bmi
FROM IncomeDetails i
JOIN patients p ON i.patient_id = p.patient_id
LEFT JOIN VitalStats vs ON i.patient_id = vs.patient_id
WHERE i.income_bracket IN ('L', 'M')
ORDER BY vs.bmi DESC;

WITH SurveyScores AS (
    SELECT patient_id, MAX(survey_date) AS recent_survey_date, AVG(survey_score) AS avg_score
    FROM surveys
    GROUP BY patient_id
)
SELECT ss.patient_id, p.first_name, p.last_name, 
       ss.recent_survey_date, ss.avg_score, ct.team_name
FROM SurveyScores ss
JOIN patients p ON ss.patient_id = p.patient_id
LEFT JOIN patient_care_team pct ON p.patient_id = pct.patient_id
LEFT JOIN care_teams ct ON pct.care_team_id = ct.care_team_id
WHERE ss.avg_score > 75
ORDER BY ss.avg_score DESC;

WITH RecentProcedures AS (
    SELECT visit_id, procedure_code, COUNT(procedure_id) AS procedure_count
    FROM procedures
    WHERE procedure_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY visit_id, procedure_code
),
ClaimDetails AS (
    SELECT claim_id, visit_id, billed_amount, claim_status
    FROM claims
    WHERE claim_date > CURRENT_DATE - INTERVAL '2 years'
)
SELECT rp.visit_id, p.first_name, p.last_name,
       rp.procedure_code, rp.procedure_count,
       AVG(cd.billed_amount) AS avg_billed_amount
FROM RecentProcedures rp
JOIN visits v ON rp.visit_id = v.visit_id
JOIN patients p ON v.patient_id = p.patient_id
LEFT JOIN ClaimDetails cd ON rp.visit_id = cd.visit_id
WHERE cd.claim_status = 'Paid'
GROUP BY rp.visit_id, p.first_name, p.last_name, rp.procedure_code, rp.procedure_count
HAVING rp.procedure_count > 2
ORDER BY avg_billed_amount DESC;