-- Query 1
WITH RecentVisits AS (
    SELECT patient_id, MAX(visit_date) AS last_visit_date
    FROM visits
    GROUP BY patient_id
),
AverageVitals AS (
    SELECT visit_id, AVG(blood_pressure_systolic) AS avg_systolic, AVG(blood_pressure_diastolic) AS avg_diastolic
    FROM vitals
    GROUP BY visit_id
)
SELECT p.patient_id, p.first_name, p.last_name, rv.last_visit_date, 
       AVG(av.avg_systolic) OVER(PARTITION BY p.gender) AS gender_systolic_avg,
       AVG(av.avg_diastolic) OVER(PARTITION BY r.race_ethnicity_name) AS race_diastolic_avg
FROM patients p
JOIN RecentVisits rv ON p.patient_id = rv.patient_id
JOIN visits v ON rv.patient_id = v.patient_id
JOIN AverageVitals av ON v.visit_id = av.visit_id
JOIN race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
WHERE EXTRACT(YEAR FROM AGE(rv.last_visit_date, p.date_of_birth)) > 40
HAVING COUNT(v.visit_id) > 1
ORDER BY gender_systolic_avg DESC;

-- Query 2
WITH ProcedureCounts AS (
    SELECT visit_id, COUNT(procedure_id) AS procedure_count
    FROM procedures
    GROUP BY visit_id
),
CommonMedications AS (
    SELECT m.medication_name, COUNT(*) AS freq
    FROM medications m
    GROUP BY m.medication_name
    HAVING COUNT(*) > 5
)
SELECT p.patient_id, p.first_name, p.last_name, v.visit_date, pc.procedure_count, 
       CASE 
           WHEN cm.freq IS NOT NULL THEN 'Common'
           ELSE 'Rare'
       END AS common_medication_flag
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN ProcedureCounts pc ON v.visit_id = pc.visit_id
LEFT JOIN CommonMedications cm ON v.visit_id IN (
    SELECT m.visit_id
    FROM medications m
    WHERE m.medication_name = cm.medication_name
)
ORDER BY pc.procedure_count DESC;

-- Query 3
WITH DiagnosedConditions AS (
    SELECT c.patient_id, COUNT(DISTINCT c.condition_name) AS condition_count
    FROM conditions c
    GROUP BY c.patient_id
),
AllergySeverities AS (
    SELECT a.patient_id, 
           MAX(CASE WHEN a.severity = 'High' THEN 1 ELSE 0 END) AS high_severity
    FROM allergies a
    GROUP BY a.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, dc.condition_count,
       ARRAY_AGG(DISTINCT s.sdoh_type) AS sdoh_factors,
       CASE 
           WHEN asr.high_severity = 1 THEN 'High Risk'
           ELSE 'Low Risk'
       END AS risk_level
FROM patients p
LEFT JOIN DiagnosedConditions dc ON p.patient_id = dc.patient_id
LEFT JOIN sdoh_entries s ON p.patient_id = s.patient_id
LEFT JOIN AllergySeverities asr ON p.patient_id = asr.patient_id
WHERE EXISTS (
    SELECT 1
    FROM conditions c
    WHERE c.patient_id = p.patient_id AND c.condition_status = 'Active'
)
GROUP BY p.patient_id, dc.condition_count, asr.high_severity;

-- Query 4
WITH AdmissionDetails AS (
    SELECT v.visit_id,
           SUM(EXTRACT(EPOCH FROM (v.discharge_time - v.admission_time)) / 3600) AS total_hours
    FROM visits v
    WHERE v.was_emergency = TRUE
    GROUP BY v.visit_id
),
TopDiagnoses AS (
    SELECT d.diagnosis_code, COUNT(*) AS diagnosis_freq
    FROM diagnoses d
    GROUP BY d.diagnosis_code
    HAVING COUNT(*) > 10
)
SELECT p.patient_id, p.first_name, p.last_name, ad.total_hours,
       STRING_AGG(DISTINCT d.diagnosis_code, ', ') AS frequent_diagnoses_codes,
       MAX(CASE WHEN si.survey_score > 80 THEN 'High Satisfaction'
                ELSE 'Low Satisfaction'
           END) AS satisfaction_level
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN diagnoses d ON v.visit_id = d.visit_id
JOIN AdmissionDetails ad ON v.visit_id = ad.visit_id
JOIN surveys si ON p.patient_id = si.patient_id
WHERE d.diagnosis_code IN (SELECT diagnosis_code FROM TopDiagnoses)
GROUP BY p.patient_id, ad.total_hours;

-- Query 5
WITH AverageScores AS (
    SELECT rs.patient_id, AVG(rs.score_value) AS avg_score
    FROM risk_scores rs
    GROUP BY rs.patient_id
),
ProviderSpecialtyStats AS (
    SELECT v.provider_id, pr.specialty, COUNT(v.visit_id) AS visit_count
    FROM visits v
    JOIN providers pr ON v.provider_id = pr.provider_id
    GROUP BY v.provider_id, pr.specialty
    HAVING COUNT(v.visit_id) > 5
)
SELECT p.patient_id, p.first_name, p.last_name, avr.avg_score,
       ARRAY_AGG(DISTINCT prs.specialty) AS frequent_specialties
FROM patients p
LEFT JOIN AverageScores avr ON p.patient_id = avr.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN ProviderSpecialtyStats prs ON v.provider_id = prs.provider_id
LEFT JOIN claims c ON v.visit_id = c.visit_id
WHERE c.claim_status = 'Paid' AND avr.avg_score > 70
GROUP BY p.patient_id, avr.avg_score;

-- Query 6
WITH ImagingSummaries AS (
    SELECT v.patient_id, COUNT(i.imaging_id) AS total_imagings,
           AVG(EXTRACT(YEAR FROM AGE(i.performed_date, p.date_of_birth))) AS avg_age_at_imaging
    FROM imaging i
    JOIN visits v ON i.visit_id = v.visit_id
    JOIN patients p ON v.patient_id = p.patient_id
    GROUP BY v.patient_id
),
IncomeStatus AS (
    SELECT i.patient_id, MAX(i.income_level) AS max_income
    FROM income_brackets i
    GROUP BY i.patient_id
    HAVING COUNT(DISTINCT i.income_level) > 1
)
SELECT p.patient_id, p.first_name, p.last_name, is.max_income,
       CASE WHEN im.total_imagings > 5 THEN 'Frequent Imaging'
            ELSE 'Infrequent Imaging'
       END AS imaging_frequency
FROM patients p
LEFT JOIN ImagingSummaries im ON p.patient_id = im.patient_id
LEFT JOIN IncomeStatus is ON p.patient_id = is.patient_id
WHERE im.avg_age_at_imaging > 30
ORDER BY im.total_imagings DESC;

-- Query 7
WITH EmergencyVisits AS (
    SELECT v.visit_id, p.patient_id, count(*) AS emergency_count
    FROM visits v
    JOIN patients p ON v.patient_id = p.patient_id
    WHERE v.was_emergency = TRUE
    GROUP BY v.visit_id, p.patient_id
),
HighCostClaims AS (
    SELECT c.patient_id, SUM(c.paid_amount) AS total_paid
    FROM claims c
    WHERE c.claim_amount > 1000
    GROUP BY c.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, 
       SUM(ev.emergency_count) AS total_emergencies, hc.total_paid
FROM patients p
JOIN EmergencyVisits ev ON p.patient_id = ev.patient_id
LEFT JOIN HighCostClaims hc ON p.patient_id = hc.patient_id
WHERE hc.total_paid IS NOT NULL
GROUP BY p.patient_id, hc.total_paid
HAVING hc.total_paid > 5000;

-- Query 8
WITH LanguagePatients AS (
    SELECT l.language_name, COUNT(*) AS patient_count
    FROM patients p
    JOIN languages l ON p.language_id = l.language_id
    GROUP BY l.language_name
),
RecentSurveys AS (
    SELECT s.patient_id, MAX(s.survey_date) AS last_survey_date
    FROM surveys s
    GROUP BY s.patient_id
    HAVING MAX(s.survey_date) > CURRENT_DATE - INTERVAL '1 year'
)
SELECT lp.language_name, lp.patient_count, 
       AVG(rs.score_value) OVER(ORDER BY lp.patient_count) AS running_avg_score
FROM LanguagePatients lp
JOIN RecentSurveys rs ON lp.patient_count > rs.patient_id
WHERE lp.language_name IN (
    SELECT language_name FROM languages WHERE language_name LIKE 'Eng%'
);

-- Query 9
WITH ConditionHistory AS (
    SELECT c.patient_id, STRING_AGG(c.condition_name, ', ') AS conditions
    FROM conditions c
    WHERE c.condition_status = 'Resolved'
    GROUP BY c.patient_id
),
AllergyReaction AS (
    SELECT a.patient_id, COUNT(a.allergy_id) AS allergy_count
    FROM allergies a
    WHERE a.severity = 'Severe'
    GROUP BY a.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, ch.conditions,
       COUNT(DISTINCT a.allergen) AS distinct_allergens, ar.allergy_count
FROM patients p
LEFT JOIN ConditionHistory ch ON p.patient_id = ch.patient_id
LEFT JOIN allergies a ON p.patient_id = a.patient_id
LEFT JOIN AllergyReaction ar ON p.patient_id = ar.patient_id
WHERE ar.allergy_count > 2
AND EXISTS (
    SELECT 1
    FROM medications m
    WHERE m.patient_id = p.patient_id AND m.medication_name = 'Aspirin'
);

-- Query 10
WITH CareTeamParticipation AS (
    SELECT pct.patient_id, COUNT(ct.care_team_id) AS team_count
    FROM patient_care_team pct
    JOIN care_teams ct ON pct.care_team_id = ct.care_team_id
    GROUP BY pct.patient_id
),
LabResults AS (
    SELECT l.visit_id, SUM(l.result_value) AS total_lab_value
    FROM labs l
    WHERE l.result_flag = 'Abnormal'
    GROUP BY l.visit_id
)
SELECT p.patient_id, p.first_name, p.last_name,
       ct.team_count, SUM(lr.total_lab_value) AS total_abnormal_results
FROM patients p
LEFT JOIN CareTeamParticipation ct ON p.patient_id = ct.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN LabResults lr ON v.visit_id = lr.visit_id
WHERE lr.total_lab_value > 
    (SELECT AVG(l.result_value) FROM labs l WHERE l.result_flag = 'Abnormal')
GROUP BY p.patient_id, ct.team_count;