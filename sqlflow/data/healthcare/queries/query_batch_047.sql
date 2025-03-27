-- Query 1
WITH RecentVisits AS (
    SELECT patient_id, MAX(visit_date) AS last_visit_date
    FROM visits
    GROUP BY patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, COUNT(v.visit_id) AS total_visits,
       AVG(ps.survey_score) OVER (PARTITION BY p.gender) AS avg_survey_score_by_gender
FROM patients p
JOIN RecentVisits rv ON p.patient_id = rv.patient_id
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN surveys ps ON p.patient_id = ps.patient_id AND ps.survey_date = rv.last_visit_date
JOIN (
    SELECT provider_id, COUNT(*) AS provider_visits
    FROM visits
    WHERE was_emergency = TRUE
    GROUP BY provider_id
    HAVING COUNT(*) > 5
) ep ON v.provider_id = ep.provider_id
WHERE rv.last_visit_date > '2020-01-01'
GROUP BY p.patient_id, ps.survey_score
HAVING COUNT(v.visit_id) > 10;

-- Query 2
WITH HighRiskPatients AS (
    SELECT patient_id
    FROM risk_scores
    WHERE score_value > 8
)
SELECT p.patient_id, p.first_name, p.last_name, i.payer_name,
       SUM(claim.claim_amount) AS total_claims_amount,
       ROUND(AVG(payment.amount), 2) AS avg_payment_amount
FROM patients p
JOIN HighRiskPatients hr ON p.patient_id = hr.patient_id
JOIN insurance i ON p.insurance_id = i.insurance_id
JOIN claims claim ON p.patient_id = claim.patient_id
LEFT JOIN payments payment ON claim.claim_id = payment.claim_id
JOIN (
    SELECT patient_id, MAX(diagnosed_date) AS max_diagnosed_date
    FROM conditions
    GROUP BY patient_id
) cd ON p.patient_id = cd.patient_id
WHERE cd.max_diagnosed_date > '2021-01-01'
GROUP BY p.patient_id, i.payer_name
HAVING SUM(claim.claim_amount) > 5000;

-- Query 3
WITH AllergyInfo AS (
    SELECT a1.patient_id, COUNT(a1.allergy_id) AS total_allergies
    FROM allergies a1
    GROUP BY a1.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, a.street_address, a.city,
       CASE 
           WHEN e.employment_type = 'Full-Time' THEN 'Employed Full-Time'
           WHEN e.employment_type = 'Unemployed' THEN 'Unemployed'
           ELSE 'Other'
       END AS employment_status,
       te.team_name, ai.total_allergies
FROM patients p
JOIN addresses a ON p.address_id = a.address_id
JOIN employment_status e ON p.patient_id = e.patient_id
LEFT JOIN patient_care_team pct ON p.patient_id = pct.patient_id
JOIN care_teams te ON te.care_team_id = pct.care_team_id
LEFT JOIN AllergyInfo ai ON p.patient_id = ai.patient_id
JOIN (
    SELECT patient_id, MAX(survey_score) AS highest_survey_score
    FROM surveys
    GROUP BY patient_id
) hs ON p.patient_id = hs.patient_id
WHERE hs.highest_survey_score > 50
ORDER BY ai.total_allergies DESC;

-- Query 4
WITH SubCons AS (
    SELECT condition_id, cond.patient_id, COUNT(*) OVER (PARTITION BY cond.patient_id) AS total_conditions
    FROM conditions cond
    JOIN patients p ON cond.patient_id = p.patient_id
)
SELECT p.first_name, p.last_name, COUNT(s.visit_id) AS symptom_related_visits,
       MAX(v.visit_date) AS most_recent_visit_date, ic.income_level
FROM patients p
JOIN SubCons sc ON p.patient_id = sc.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN symptoms s ON v.visit_id = s.visit_id
LEFT JOIN income_brackets ic ON p.patient_id = ic.patient_id
JOIN (
    SELECT symptom_id, COUNT(*) AS freq
    FROM symptoms
    GROUP BY symptom_id
) sf ON s.symptom_id = sf.symptom_id
WHERE sf.freq > 3
GROUP BY p.patient_id, ic.income_level
HAVING COUNT(s.visit_id) > 5;

-- Query 5
WITH MedicationsCount AS (
    SELECT patient_id, COUNT(medication_id) AS num_medications
    FROM medications m
    JOIN visits v ON m.visit_id = v.visit_id
    GROUP BY patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, e.language_name,
       CASE 
           WHEN mc.num_medications > 5 THEN 'High'
           WHEN mc.num_medications BETWEEN 3 AND 5 THEN 'Medium'
           ELSE 'Low'
       END AS medication_level,
       ROUND(AVG(rs.score_value) OVER (PARTITION BY p.gender), 1) AS avg_risk_by_gender
FROM patients p
LEFT JOIN languages e ON p.language_id = e.language_id
JOIN MedicationsCount mc ON p.patient_id = mc.patient_id
LEFT JOIN risk_scores rs ON p.patient_id = rs.patient_id
JOIN (
    SELECT race_ethnicity_id, race_ethnicity_name
    FROM race_ethnicity
    WHERE race_ethnicity_name IS NOT NULL
) re ON p.race_ethnicity_id = re.race_ethnicity_id
WHERE re.race_ethnicity_name IN ('Asian', 'Hispanic')
ORDER BY medication_level DESC;

-- Query 6
WITH PatientDiagnosis AS (
    SELECT d.patient_id, MAX(d.diagnosis_date) AS last_diagnosis_date
    FROM diagnoses d
    JOIN visits v ON d.visit_id = v.visit_id
    GROUP BY d.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, COUNT(proc.procedure_id) AS procedure_count,
       AVG(l.result_value) AS avg_result_value,
       CASE 
           WHEN v.was_emergency THEN 'Emergency'
           ELSE 'Regular'
       END AS visit_type
FROM patients p
JOIN PatientDiagnosis pd ON p.patient_id = pd.patient_id
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN procedures proc ON v.visit_id = proc.visit_id
LEFT JOIN labs l ON v.visit_id = l.visit_id
JOIN (
    SELECT v.visit_id, v.reason_for_visit
    FROM visits v
    WHERE v.reason_for_visit LIKE '%pain%'
    UNION ALL
    SELECT v.visit_id, v.reason_for_visit
    FROM visits v
    WHERE v.reason_for_visit LIKE '%fever%'
) reason ON v.visit_id = reason.visit_id
GROUP BY p.patient_id, visit_type
HAVING COUNT(proc.procedure_id) > 2;

-- Query 7
WITH SymptomScores AS (
    SELECT visit_id, AVG(rs.score_value) AS avg_score
    FROM risk_scores rs
    JOIN visits v ON rs.patient_id = v.patient_id
    GROUP BY visit_id
)
SELECT v.visit_id, p.first_name, p.last_name, COUNT(s.symptom_id) AS symptom_count,
       MAX(v.admission_time) OVER (PARTITION BY p.language_id) AS max_admission_by_language,
       SUM(b.amount) OVER () AS total_billing_amount
FROM visits v
JOIN patients p ON v.patient_id = p.patient_id
LEFT JOIN symptoms s ON v.visit_id = s.visit_id
LEFT JOIN billing b ON v.visit_id = b.claim_id
JOIN SymptomScores ss ON v.visit_id = ss.visit_id
WHERE p.gender = 'Female'
GROUP BY v.visit_id, p.first_name, p.last_name
HAVING COUNT(s.symptom_id) > 1;

-- Query 8
WITH ProviderVisitStats AS (
    SELECT provider_id, AVG(claim.paid_amount) AS avg_claim_payment
    FROM claims claim
    JOIN visits v ON claim.visit_id = v.visit_id
    GROUP BY provider_id
)
SELECT pr.provider_id, pr.first_name, pr.last_name, pr.specialty,
       COUNT(v.visit_id) AS total_visits,
       ROUND(SUM(claim.claim_amount), 2) AS total_claims_amount,
       CASE 
           WHEN pv.avg_claim_payment > 1000 THEN 'High Paying'
           ELSE 'Regular'
       END AS payment_category
FROM providers pr
JOIN visits v ON pr.provider_id = v.provider_id
JOIN claims claim ON v.visit_id = claim.visit_id
LEFT JOIN ProviderVisitStats pv ON pr.provider_id = pv.provider_id
JOIN (
    SELECT doctor_id, COUNT(imaging_type) AS imaging_count
    FROM imaging
    WHERE imaging_type = 'X-Ray'
    GROUP BY doctor_id
) im ON pr.provider_id = im.doctor_id
WHERE im.imaging_count > 10
GROUP BY pr.provider_id, payment_category
ORDER BY total_visits DESC;

-- Query 9
WITH LatestVitals AS (
    SELECT visit_id, MAX(recorded_at) AS latest_record
    FROM vitals
    GROUP BY visit_id
)
SELECT p.patient_id, p.first_name, p.last_name, COUNT(cn.note_id) AS note_count,
       COALESCE(SUM(pa.amount), 0) AS total_payment_amount,
       NVL(MAX(im.performed_date), 'N/A') AS latest_imaging_date
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN LatestVitals lv ON v.visit_id = lv.visit_id
JOIN clinical_notes cn ON v.visit_id = cn.visit_id
LEFT JOIN payments pa ON v.visit_id = pa.claim_id
LEFT JOIN imaging im ON v.visit_id = im.visit_id
JOIN (
    SELECT condition_id, COUNT(*) AS condition_count
    FROM conditions
    GROUP BY condition_id
    HAVING COUNT(*) > 1
) cond ON p.patient_id = cond.patient_id
WHERE v.admission_time BETWEEN '2021-01-01' AND '2022-12-31'
GROUP BY p.patient_id
HAVING note_count > 5;

-- Query 10
WITH EmergencyVisits AS (
    SELECT v.visit_id, COUNT(*) AS emergency_count
    FROM visits v
    WHERE v.was_emergency
    GROUP BY v.visit_id
)
SELECT p.first_name, p.gender, COUNT(s.screening_id) AS screening_count,
       AVG(e.result_value) AS avg_lab_result,
       CASE 
           WHEN e.result_flag = 'High' THEN 'Follow Up Required'
           WHEN e.result_flag = 'Low' THEN 'Monitor'
           ELSE 'Normal'
       END AS result_assessment
FROM patients p
JOIN emergency_visits ev ON p.patient_id = ev.patient_id
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN screenings s ON p.patient_id = s.patient_id
LEFT JOIN labs e ON v.visit_id = e.visit_id
JOIN (
    SELECT d.visit_id, MAX(diagnosis_date) AS last_diagnosis
    FROM diagnoses d
    GROUP BY d.visit_id
) ld ON v.visit_id = ld.visit_id
WHERE p.gender IN ('Male', 'Female')
GROUP BY p.first_name, p.gender, result_assessment
HAVING screening_count > 2;